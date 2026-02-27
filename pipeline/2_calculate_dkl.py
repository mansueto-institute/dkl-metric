"""
2_calculate_dkl.py
==================
Load cleaned block-group data from 1_clean.py, apply calculate_dkl(),
and save the results.

Mirrors: one-way-dkl/all_states_block/2_calculate_dkl_2020_xwalk.R

Usage
-----
    python 2_calculate_dkl.py [--years 2015 2020] [--vars race income educ empl]

Output files
------------
    data/acs5_block_{year}_data/dkl_{var_group}_{yr_short}_blkgrp_all_states.parquet
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))

from config import DATA_DIR, YEAR_CONFIGS
from utils.dkl import calculate_dkl

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def _clean_path(year: int, var_group: str, geo: str = "blockgroup") -> Path:
    yr_short = str(year)[2:]
    if geo == "tract":
        return DATA_DIR / f"acs5_tract_{year}_data" / f"{var_group}_{yr_short}_tract_all_states.parquet"
    return DATA_DIR / f"acs5_block_{year}_data" / f"{var_group}_{yr_short}_blkgrp_all_states.parquet"


def _dkl_path(year: int, var_group: str, geo: str = "blockgroup") -> Path:
    yr_short = str(year)[2:]
    if geo == "tract":
        return DATA_DIR / f"acs5_tract_{year}_data" / f"dkl_{var_group}_{yr_short}_tract_all_states.parquet"
    return DATA_DIR / f"acs5_block_{year}_data" / f"dkl_{var_group}_{yr_short}_blkgrp_all_states.parquet"


def run_dkl_for_year(year: int, var_groups: list[str], geo: str = "blockgroup") -> None:
    """Calculate DKL for all variable groups in a given year."""
    config = YEAR_CONFIGS[year]

    for vg in var_groups:
        if vg not in config["available_vars"]:
            logger.warning("Skipping %s for %d — not in available_vars.", vg, year)
            continue

        clean_path = _clean_path(year, vg, geo)
        if not clean_path.exists():
            logger.error("Clean file not found: %s — run 1_clean.py --geo %s first.", clean_path, geo)
            continue

        out_path = _dkl_path(year, vg, geo)
        if out_path.exists():
            logger.info("Already exists, skipping: %s", out_path.name)
            continue

        logger.info("Calculating DKL for %d — %s (%s) …", year, vg, geo)
        df = pd.read_parquet(clean_path)
        dkl_df = calculate_dkl(df)
        dkl_df.to_parquet(out_path, index=False)
        logger.info("Saved %s (%d rows)", out_path.name, len(dkl_df))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Calculate DKL for cleaned Census data.")
    parser.add_argument("--years", nargs="+", default=["2015", "2020"])
    parser.add_argument(
        "--vars", nargs="+", default=["race", "income", "educ", "empl"],
        choices=["race", "income", "educ", "empl"],
    )
    parser.add_argument(
        "--geo", default="blockgroup", choices=["blockgroup", "tract"],
        help="Geographic level (default: blockgroup).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    for yr_str in args.years:
        yr = int(yr_str)
        if yr not in YEAR_CONFIGS:
            logger.warning("Year %d not in YEAR_CONFIGS — skipping.", yr)
            continue
        run_dkl_for_year(yr, args.vars, geo=args.geo)
