"""
4_mutual_info.py
================
Load DKL Parquet files from 2_calculate_dkl.py and 3_income_2010.py,
compute per-metro mutual information (MI), and save MI summaries.

Mirrors: one-way-dkl/all_states_block/4_get_mutual_info_summaries.R

MI(cbsa) = population-weighted mean of dkl_block, where weights = p_ni
         = Σ_i p_ni * dkl_block[i]

Usage
-----
    python 4_mutual_info.py

Output files
------------
    data/acs5_block_{year}_data/mi_{var_group}_{yr_short}_blkgrp_all_states.parquet
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))

from config import DATA_DIR
from utils.dkl import get_mutual_info

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _dkl_path(year_tag: str, var_group: str, geo: str = "blockgroup") -> Path:
    """Return the expected path for a DKL parquet file.

    year_tag examples: '15', '20', '10'
    """
    full_year = "20" + year_tag if int(year_tag) < 50 else "19" + year_tag
    if geo == "tract":
        return DATA_DIR / f"acs5_tract_{full_year}_data" / f"dkl_{var_group}_{year_tag}_tract_all_states.parquet"
    return DATA_DIR / f"acs5_block_{full_year}_data" / f"dkl_{var_group}_{year_tag}_blkgrp_all_states.parquet"


def _mi_path(year_tag: str, var_group: str, geo: str = "blockgroup") -> Path:
    full_year = "20" + year_tag if int(year_tag) < 50 else "19" + year_tag
    if geo == "tract":
        d = DATA_DIR / f"acs5_tract_{full_year}_data"
        d.mkdir(parents=True, exist_ok=True)
        return d / f"mi_{var_group}_{year_tag}_tract_all_states.parquet"
    d = DATA_DIR / f"acs5_block_{full_year}_data"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"mi_{var_group}_{year_tag}_blkgrp_all_states.parquet"


def save_mi_file(var_group: str, year_tag: str, *, dkl_path: Path | None = None,
                 geo: str = "blockgroup") -> None:
    """Load a DKL file, compute MI, and save the result.

    Parameters
    ----------
    var_group : str
        e.g. 'race', 'income', 'educ', 'empl'
    year_tag : str
        Short year string, e.g. '15', '20', '10'
    dkl_path : Path, optional
        Override the default file path.
    geo : {'blockgroup', 'tract'}
    """
    path = dkl_path or _dkl_path(year_tag, var_group, geo)
    out_path = _mi_path(year_tag, var_group, geo)

    if not path.exists():
        logger.warning("DKL file not found, skipping: %s", path)
        return

    if out_path.exists():
        logger.info("Already exists, skipping: %s", out_path.name)
        return

    logger.info("Computing MI for %s %s …", var_group, year_tag)
    dkl_df = pd.read_parquet(path)

    # Ensure required columns exist
    required = ["block_fips", "variable_group", "group_label", "block_total",
                "dkl_block", "p_ni", "cbsa_title", "cbsa_total", "state_codes"]
    missing = [c for c in required if c not in dkl_df.columns]
    if missing:
        logger.error("Missing columns in %s: %s", path.name, missing)
        return

    mi_df = get_mutual_info(dkl_df)
    mi_df.to_parquet(out_path, index=False)
    logger.info("Saved %s (%d rows)", out_path.name, len(mi_df))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compute mutual information from DKL files.")
    parser.add_argument(
        "--geo", default="blockgroup", choices=["blockgroup", "tract"],
        help="Geographic level to process (default: blockgroup).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    import argparse
    args = parse_args()
    geo = args.geo

    # All four variable groups for 2010, 2015, 2020
    for vg in ("income", "race", "educ", "empl"):
        for yr in ("10", "15", "20"):
            save_mi_file(vg, yr, geo=geo)
