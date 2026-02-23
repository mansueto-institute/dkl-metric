"""
0_download.py
=============
Download block-group level ACS/Decennial Census data for all 50 US states
and save each variable group as a Parquet file.

Mirrors: one-way-dkl/all_states_block/0_download_all_metro_data.R

Usage
-----
    python 0_download.py [--years 2015 2020] [--vars race income educ empl]

The script also includes a smoke-test (run automatically on first call) that
fetches a single ACS variable for IL in 2020 to verify the API key and
`census` package are working before running the full pipeline.

Output files
------------
    data/acs5_block_{year}_data/raw/{var_group}_blkgrp_all_states_{year}.parquet
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Project imports
# ---------------------------------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent))

from config import CENSUS_API_KEY, DATA_DIR, STATE_CODES, YEAR_CONFIGS
from utils.census_api import fetch_all_states, fetch_block_group_data
from utils.variable_maps import (
    ACS_EMPL_VARS,
    ACS_EDUC_VARS,
    ACS_INCOME_VARS,
    ACS_RACE_VARS,
    SF1_2010_HISP_VARS,
    SF1_2010_RACE_VARS,
    SF1_2000_HISP_VARS,
    SF1_2000_RACE_VARS,
    SF3_2000_EDUC_VARS,
    SF3_2000_EMPL_VARS,
    SF3_2000_INCOME_VARS,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Variable group definitions per dataset
# ---------------------------------------------------------------------------

ACS_VAR_GROUPS = {
    "race":   (list(ACS_RACE_VARS),   ACS_RACE_VARS),
    "income": (list(ACS_INCOME_VARS), ACS_INCOME_VARS),
    "educ":   (list(ACS_EDUC_VARS),   ACS_EDUC_VARS),
    "empl":   (list(ACS_EMPL_VARS),   ACS_EMPL_VARS),
}

DEC_2010_VAR_GROUPS = {
    "race": (
        list({**SF1_2010_RACE_VARS, **SF1_2010_HISP_VARS}),
        {**SF1_2010_RACE_VARS, **SF1_2010_HISP_VARS},
    ),
}

DEC_2000_SF1_VAR_GROUPS = {
    "race": (
        list({**SF1_2000_RACE_VARS, **SF1_2000_HISP_VARS}),
        {**SF1_2000_RACE_VARS, **SF1_2000_HISP_VARS},
    ),
}

DEC_2000_SF3_VAR_GROUPS = {
    "income": (list(SF3_2000_INCOME_VARS), SF3_2000_INCOME_VARS),
    "educ":   (list(SF3_2000_EDUC_VARS),   SF3_2000_EDUC_VARS),
    "empl":   (list(SF3_2000_EMPL_VARS),   SF3_2000_EMPL_VARS),
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _output_dir(year: int | str, dataset: str) -> Path:
    year_str = str(year).replace("dec", "")
    suffix = f"_{dataset}" if dataset not in ("acs5",) else ""
    d = DATA_DIR / f"acs5_block_{year_str}_data{suffix}" / "raw"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _save(df: pd.DataFrame, path: Path) -> None:
    df.to_parquet(path, index=False)
    logger.info("Saved %s (%d rows)", path.name, len(df))


def download_year(year: int, var_groups: list[str]) -> None:
    """Download ACS 5-year data for a single year."""
    config = YEAR_CONFIGS[year]
    assert config["dataset"] == "acs5", f"Use download_decennial for year={year}"

    out_dir = _output_dir(year, "acs5")

    for vg in var_groups:
        if vg not in config["available_vars"]:
            logger.warning("Skipping %s for year %d (not available)", vg, year)
            continue

        codes, label_map = ACS_VAR_GROUPS[vg]
        out_path = out_dir / f"{vg}_blkgrp_all_states_{year}.parquet"
        if out_path.exists():
            logger.info("Already exists, skipping: %s", out_path.name)
            continue

        logger.info("Downloading ACS5 %d — %s …", year, vg)
        df = fetch_all_states(
            year=year,
            dataset="acs5",
            variables=codes,
            state_codes=STATE_CODES,
            api_key=CENSUS_API_KEY,
            var_label_map=label_map,
        )
        _save(df, out_path)


def download_decennial_2010(var_groups: list[str]) -> None:
    """Download 2010 Decennial Census SF1 data (race only)."""
    config = YEAR_CONFIGS["2010dec"]
    out_dir = _output_dir("2010dec", "sf1")

    for vg in var_groups:
        if vg not in config["available_vars"]:
            logger.warning("Skipping %s for 2010dec (not available in SF1)", vg)
            continue

        codes, label_map = DEC_2010_VAR_GROUPS[vg]
        out_path = out_dir / f"{vg}_blkgrp_all_states_2010dec.parquet"
        if out_path.exists():
            logger.info("Already exists, skipping: %s", out_path.name)
            continue

        logger.info("Downloading 2010 SF1 — %s …", vg)
        df = fetch_all_states(
            year=2010,
            dataset="sf1",
            variables=codes,
            state_codes=STATE_CODES,
            api_key=CENSUS_API_KEY,
            var_label_map=label_map,
        )
        _save(df, out_path)


def download_decennial_2000(var_groups: list[str]) -> None:
    """Download 2000 Decennial Census SF1 (race) and SF3 (income/educ/empl)."""
    config = YEAR_CONFIGS["2000dec"]

    if "race" in var_groups:
        out_dir = _output_dir("2000dec", "sf1")
        codes, label_map = DEC_2000_SF1_VAR_GROUPS["race"]
        out_path = out_dir / "race_blkgrp_all_states_2000dec.parquet"
        if not out_path.exists():
            logger.info("Downloading 2000 SF1 — race …")
            df = fetch_all_states(
                year=2000, dataset="sf1", variables=codes,
                state_codes=STATE_CODES, api_key=CENSUS_API_KEY,
                var_label_map=label_map,
            )
            _save(df, out_path)

    for vg in ("income", "educ", "empl"):
        if vg not in var_groups:
            continue
        if vg not in config["available_vars"]:
            continue
        out_dir = _output_dir("2000dec", "sf3")
        codes, label_map = DEC_2000_SF3_VAR_GROUPS[vg]
        out_path = out_dir / f"{vg}_blkgrp_all_states_2000dec.parquet"
        if not out_path.exists():
            logger.info("Downloading 2000 SF3 — %s …", vg)
            df = fetch_all_states(
                year=2000, dataset="sf3", variables=codes,
                state_codes=STATE_CODES, api_key=CENSUS_API_KEY,
                var_label_map=label_map,
            )
            _save(df, out_path)


# ---------------------------------------------------------------------------
# Smoke tests
# ---------------------------------------------------------------------------

def smoke_test_acs() -> None:
    """Fetch a single ACS variable for IL in 2020 to verify the API key."""
    print("\n=== Smoke test: ACS 5-year 2020 (IL) ===")
    df = fetch_block_group_data(
        year=2020,
        dataset="acs5",
        variables=["B19001_001"],
        state="IL",
        api_key=CENSUS_API_KEY,
        var_label_map={"B19001_001": "Total households"},
    )
    if df.empty:
        print("WARNING: No data returned — check your CENSUS_API_KEY.")
    else:
        print(df.head())
        print(f"  ✓ Received {len(df)} rows for IL 2020 ACS5.")


def smoke_test_sf1() -> None:
    """Fetch a single SF1 variable for IL in 2010 to verify Decennial access."""
    print("\n=== Smoke test: 2010 Decennial SF1 (IL) ===")
    df = fetch_block_group_data(
        year=2010,
        dataset="sf1",
        variables=["P003001"],
        state="IL",
        api_key=CENSUS_API_KEY,
        var_label_map={"P003001": "Total population (race)"},
    )
    if df.empty:
        print("WARNING: No data returned — check your CENSUS_API_KEY.")
    else:
        print(df.head())
        print(f"  ✓ Received {len(df)} rows for IL 2010 SF1.")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download Census block-group data.")
    parser.add_argument(
        "--years", nargs="+", default=["2015", "2020"],
        help="Years to download. Use integers for ACS (e.g. 2015 2020) or "
             "'2010dec' / '2000dec' for Decennial Census.",
    )
    parser.add_argument(
        "--vars", nargs="+", default=["race", "income", "educ", "empl"],
        choices=["race", "income", "educ", "empl"],
        help="Variable groups to download.",
    )
    parser.add_argument(
        "--smoke-test", action="store_true",
        help="Run API smoke tests only; do not download full data.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    # Always run smoke tests first
    smoke_test_acs()
    smoke_test_sf1()

    if args.smoke_test:
        sys.exit(0)

    for yr_str in args.years:
        if yr_str == "2010dec":
            download_decennial_2010(args.vars)
        elif yr_str == "2000dec":
            download_decennial_2000(args.vars)
        else:
            yr = int(yr_str)
            if yr not in YEAR_CONFIGS:
                logger.warning("Year %d not in YEAR_CONFIGS — skipping.", yr)
                continue
            if YEAR_CONFIGS[yr]["dataset"] != "acs5":
                logger.warning("Year %d is not an ACS year — use '2010dec' or '2000dec'.", yr)
                continue
            download_year(yr, args.vars)
