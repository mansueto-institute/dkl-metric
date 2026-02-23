"""
1_clean.py
==========
Join raw ACS/Census block-group data to CBSA and state crosswalks,
then compute block/county/CBSA totals and percentages.

Mirrors: one-way-dkl/all_states_block/1_clean_metro_data_with_2020_cbsas.R

The default CBSA delineation used is always the *2020* delineation applied
retroactively to all years (matching the R script).  Pass --cbsa-year to
use a different vintage (e.g. 2015 for year-matched analysis).

Usage
-----
    python 1_clean.py [--years 2015 2020] [--vars race income educ empl]
                      [--cbsa-year 2020]

Output files
------------
    data/acs5_block_{year}_data/{var_group}_{yr_short}_blkgrp_all_states.parquet

Schema (matches join_metro_data output from R):
    block_fips, county_fips, county_name, cbsa_fips, cbsa_title, area_type,
    central_outlying_county, state_codes, state_fips, state_name,
    variable, variable_group, variable_item, group_label, label,
    block_pct, block_estimate, moe, block_total,
    county_pct, county_estimate, county_total,
    cbsa_pct, cbsa_estimate, cbsa_total
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))

from config import CENSUS_API_KEY, DATA_DIR, YEAR_CONFIGS
from utils.cbsa_xwalk import get_cbsa_xwalk
from utils.variable_maps import ACS_GROUP_LABELS, ACS_TOTALS

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# State crosswalk (hard-coded; mirrors tidycensus::fips_codes)
# ---------------------------------------------------------------------------

# fmt: off
_STATE_FIPS = {
    "AL": ("01", "Alabama"), "AK": ("02", "Alaska"), "AZ": ("04", "Arizona"),
    "AR": ("05", "Arkansas"), "CA": ("06", "California"), "CO": ("08", "Colorado"),
    "CT": ("09", "Connecticut"), "DE": ("10", "Delaware"), "FL": ("12", "Florida"),
    "GA": ("13", "Georgia"), "HI": ("15", "Hawaii"), "ID": ("16", "Idaho"),
    "IL": ("17", "Illinois"), "IN": ("18", "Indiana"), "IA": ("19", "Iowa"),
    "KS": ("20", "Kansas"), "KY": ("21", "Kentucky"), "LA": ("22", "Louisiana"),
    "ME": ("23", "Maine"), "MD": ("24", "Maryland"), "MA": ("25", "Massachusetts"),
    "MI": ("26", "Michigan"), "MN": ("27", "Minnesota"), "MS": ("28", "Mississippi"),
    "MO": ("29", "Missouri"), "MT": ("30", "Montana"), "NE": ("31", "Nebraska"),
    "NV": ("32", "Nevada"), "NH": ("33", "New Hampshire"), "NJ": ("34", "New Jersey"),
    "NM": ("35", "New Mexico"), "NY": ("36", "New York"), "NC": ("37", "North Carolina"),
    "ND": ("38", "North Dakota"), "OH": ("39", "Ohio"), "OK": ("40", "Oklahoma"),
    "OR": ("41", "Oregon"), "PA": ("42", "Pennsylvania"), "RI": ("44", "Rhode Island"),
    "SC": ("45", "South Carolina"), "SD": ("46", "South Dakota"), "TN": ("47", "Tennessee"),
    "TX": ("48", "Texas"), "UT": ("49", "Utah"), "VT": ("50", "Vermont"),
    "VA": ("51", "Virginia"), "WA": ("53", "Washington"), "WV": ("54", "West Virginia"),
    "WI": ("55", "Wisconsin"), "WY": ("56", "Wyoming"), "DC": ("11", "District of Columbia"),
}
# fmt: on


def _build_state_xwalk() -> pd.DataFrame:
    """Build a county-level state crosswalk (state_fips, state_name, county_fips)."""
    # We only need state-level info joined on county_fips prefix;
    # a simple prefix look-up table is sufficient.
    rows = []
    for code, (fips, name) in _STATE_FIPS.items():
        rows.append({"state_codes": code, "state_fips": fips, "state_name": name})
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Label / variable-group helpers for ACS
# ---------------------------------------------------------------------------

def _add_acs_variable_meta(df: pd.DataFrame) -> pd.DataFrame:
    """Split ACS variable codes into variable_group and variable_item columns
    and add group_label.

    Input column: 'variable'  (e.g. 'B19001_002')
    Added columns: variable_group ('B19001'), variable_item ('002'),
                   group_label ('Household Income')
    """
    df = df.copy()
    split = df["variable"].str.split("_", n=1, expand=True)
    df["variable_group"] = split[0].str.strip()
    df["variable_item"] = split[1].fillna("").str.strip()
    df["group_label"] = df["variable_group"].map(ACS_GROUP_LABELS).fillna("")
    return df


def _filter_totals(df: pd.DataFrame) -> pd.DataFrame:
    """Remove rows that are the overall total for each variable group (e.g. B19001_001).
    These are retained internally for computing block_total but should not appear
    as analysis rows.
    """
    return df[~df["variable"].isin(ACS_TOTALS)].copy()


# ---------------------------------------------------------------------------
# Core cleaning function (mirrors join_metro_data from helper_functions.R)
# ---------------------------------------------------------------------------

def join_metro_data(
    raw_df: pd.DataFrame,
    label_df: pd.DataFrame,
    cbsa_xwalk: pd.DataFrame,
    state_xwalk: pd.DataFrame,
) -> pd.DataFrame:
    """Join raw Census data to CBSA/state crosswalks and compute aggregations.

    Parameters
    ----------
    raw_df : pd.DataFrame
        Raw output from 0_download.py / utils/census_api.py.
        Required columns: geoid, variable, estimate, state, [label]
    label_df : pd.DataFrame
        Variable code → label mapping with columns: variable, label,
        variable_group, variable_item, group_label.
    cbsa_xwalk : pd.DataFrame
        CBSA crosswalk from utils/cbsa_xwalk.get_cbsa_xwalk().
    state_xwalk : pd.DataFrame
        State lookup with columns: state_codes, state_fips, state_name.

    Returns
    -------
    pd.DataFrame
        Fully joined dataset ready for 2_calculate_dkl.py.
    """
    df = raw_df.copy()
    df = df.rename(columns={"state": "state_codes", "estimate": "block_estimate"})

    # Merge variable labels
    df = df.merge(label_df, on="variable", how="inner")

    # Geographic FIPS decomposition
    df["county_fips"]  = df["geoid"].str[:5]
    df["tract"]        = df["geoid"].str[5:11]
    df["block_group"]  = df["geoid"].str[11:12]

    # Join state crosswalk on county_fips prefix (state_fips = first 2 chars)
    df["state_fips"] = df["county_fips"].str[:2]
    df = df.merge(
        state_xwalk[["state_fips", "state_name"]],
        on="state_fips", how="left",
    )

    # Join CBSA crosswalk
    df = df.merge(cbsa_xwalk, on="county_fips", how="left")

    # Keep only metro counties (cbsa_fips not null)
    df = df[df["cbsa_fips"].notna() & (df["cbsa_fips"] != "")].copy()

    # Cast estimate to numeric
    df["block_estimate"] = pd.to_numeric(df["block_estimate"], errors="coerce").fillna(0).astype(int)

    # --- Geographic aggregations ---
    # block_total: sum of all variable estimates within a block group for this group
    df["block_total"] = df.groupby(["geoid", "variable_group"])["block_estimate"].transform("sum")

    # county-level
    df["county_estimate"] = df.groupby(["county_fips", "variable"])["block_estimate"].transform("sum")
    df["county_total"]    = df.groupby(["county_fips", "variable_group"])["block_estimate"].transform("sum")

    # cbsa-level
    df["cbsa_estimate"] = df.groupby(["cbsa_fips", "variable"])["block_estimate"].transform("sum")
    df["cbsa_total"]    = df.groupby(["cbsa_fips", "variable_group"])["block_estimate"].transform("sum")

    # Percentages
    df["block_pct"]  = df["block_estimate"]  / df["block_total"].replace(0, float("nan"))
    df["county_pct"] = df["county_estimate"] / df["county_total"].replace(0, float("nan"))
    df["cbsa_pct"]   = df["cbsa_estimate"]   / df["cbsa_total"].replace(0, float("nan"))

    for col in ["block_pct", "county_pct", "cbsa_pct"]:
        df[col] = df[col].fillna(0.0)

    # Rename geoid to block_fips
    df = df.rename(columns={"geoid": "block_fips"})

    # Add moe column if missing (ACS has it, Decennial does not)
    if "moe" not in df.columns:
        df["moe"] = None

    # Select and order columns
    cols = [
        "block_fips", "county_fips", "county_name", "cbsa_fips", "cbsa_title",
        "area_type", "central_outlying_county", "state_codes", "state_fips",
        "state_name", "variable", "variable_group", "variable_item",
        "group_label", "label", "block_pct", "block_estimate", "moe",
        "block_total", "county_pct", "county_estimate", "county_total",
        "cbsa_pct", "cbsa_estimate", "cbsa_total",
    ]
    for col in cols:
        if col not in df.columns:
            df[col] = None

    return df[cols].sort_values(["county_fips", "block_fips", "variable"]).reset_index(drop=True)


# ---------------------------------------------------------------------------
# Build label DataFrame from variable maps
# ---------------------------------------------------------------------------

def build_label_df(var_group: str) -> pd.DataFrame:
    """Build the label DataFrame for a given ACS variable group."""
    from utils.variable_maps import (
        ACS_EMPL_VARS, ACS_EDUC_VARS, ACS_INCOME_VARS, ACS_RACE_VARS,
        ACS_GROUP_LABELS,
    )
    maps = {
        "race":   ACS_RACE_VARS,
        "income": ACS_INCOME_VARS,
        "educ":   ACS_EDUC_VARS,
        "empl":   ACS_EMPL_VARS,
    }
    if var_group not in maps:
        raise ValueError(f"Unknown var_group: {var_group}")
    var_map = maps[var_group]
    rows = []
    for code, label in var_map.items():
        grp = code.split("_")[0]
        item = code.split("_")[1] if "_" in code else ""
        rows.append({
            "variable": code,
            "label": label,
            "variable_group": grp,
            "variable_item": item,
            "group_label": ACS_GROUP_LABELS.get(grp, ""),
        })
    df = pd.DataFrame(rows)
    # Drop overall total rows (label == 'Total') — they're used for aggregation,
    # not as analysis categories
    df = df[df["label"] != "Total"].copy()
    return df


# ---------------------------------------------------------------------------
# Per-year processing
# ---------------------------------------------------------------------------

def _raw_path(year: int, var_group: str) -> Path:
    return DATA_DIR / f"acs5_block_{year}_data" / "raw" / f"{var_group}_blkgrp_all_states_{year}.parquet"


def _clean_path(year: int, var_group: str) -> Path:
    yr_short = str(year)[2:]  # '2015' → '15', '2020' → '20'
    d = DATA_DIR / f"acs5_block_{year}_data"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{var_group}_{yr_short}_blkgrp_all_states.parquet"


def clean_year(year: int, var_groups: list[str], cbsa_year: int = 2020) -> None:
    """Clean a single ACS year."""
    config = YEAR_CONFIGS[year]
    cbsa_xwalk = get_cbsa_xwalk(cbsa_year)
    state_xwalk = _build_state_xwalk()

    for vg in var_groups:
        if vg not in config["available_vars"]:
            logger.warning("Skipping %s for %d — not available.", vg, year)
            continue

        raw_path = _raw_path(year, vg)
        if not raw_path.exists():
            logger.error("Raw file not found: %s — run 0_download.py first.", raw_path)
            continue

        out_path = _clean_path(year, vg)
        if out_path.exists():
            logger.info("Already exists, skipping: %s", out_path.name)
            continue

        logger.info("Cleaning %d — %s …", year, vg)
        raw_df = pd.read_parquet(raw_path)
        label_df = build_label_df(vg)

        # Add county_name (not in raw data; derive from CBSA xwalk or leave empty)
        if "county_name" not in raw_df.columns:
            raw_df["county_name"] = ""

        clean_df = join_metro_data(raw_df, label_df, cbsa_xwalk, state_xwalk)
        clean_df.to_parquet(out_path, index=False)
        logger.info("Saved %s (%d rows)", out_path.name, len(clean_df))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clean raw Census data and join crosswalks.")
    parser.add_argument("--years", nargs="+", default=["2015", "2020"])
    parser.add_argument(
        "--vars", nargs="+", default=["race", "income", "educ", "empl"],
        choices=["race", "income", "educ", "empl"],
    )
    parser.add_argument(
        "--cbsa-year", type=int, default=2020,
        help="CBSA delineation year to use (default: 2020, applied retroactively).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    for yr_str in args.years:
        yr = int(yr_str)
        if yr not in YEAR_CONFIGS:
            logger.warning("Year %d not in YEAR_CONFIGS — skipping.", yr)
            continue
        clean_year(yr, args.vars, cbsa_year=args.cbsa_year)
