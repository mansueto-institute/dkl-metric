"""
3_income_2010.py
================
Process 2010 ACS income data from the local CSV file (2010acs_age.csv),
join with 2009 and 2020 CBSA crosswalks, and calculate DKL.

Mirrors: one-way-dkl/all_states_block/3_get_income_2010_dropbox_data.R

The input CSV (2010acs_all.csv) must be placed at:
    data/dropbox/2010acs_all.csv
or the path can be overridden with --input-file.

Usage
-----
    python 3_income_2010.py [--input-file path/to/2010acs_all.csv]
                             [--cbsa-years 2020 2009]

Output files
------------
    data/acs5_block_2010_data/dkl_income_10_blkgrp_all_states.parquet          (2020 CBSA xwalk)
    data/acs5_block_2010_data/cbsa_10_dkl_income_10_blkgrp_all_states.parquet  (2009 CBSA xwalk)
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))

from config import DATA_DIR
from utils.cbsa_xwalk import get_cbsa_xwalk
from utils.dkl import calculate_dkl

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Income label mapping (matches R script)
# ---------------------------------------------------------------------------

HINC_LABELS = {
    "hinc000": "Less than $10,000",
    "hinc010": "$10,000 to $14,999",
    "hinc015": "$15,000 to $19,999",
    "hinc020": "$20,000 to $24,999",
    "hinc025": "$25,000 to $29,999",
    "hinc030": "$30,000 to $34,999",
    "hinc035": "$35,000 to $39,999",
    "hinc040": "$40,000 to $44,999",
    "hinc045": "$45,000 to $49,999",
    "hinc050": "$50,000 to $59,999",
    "hinc060": "$60,000 to $74,999",
    "hinc075": "$75,000 to $99,999",
    "hinc100": "$100,000 to $124,999",
    "hinc125": "$125,000 to $149,999",
    "hinc150": "$150,000 to $199,999",
    "hinc200": "$200,000 or more",
}

# ---------------------------------------------------------------------------
# State crosswalk (same as 1_clean.py)
# ---------------------------------------------------------------------------

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


def _build_state_xwalk() -> pd.DataFrame:
    rows = [{"state_codes": code, "state_fips": fips, "state_name": name}
            for code, (fips, name) in _STATE_FIPS.items()]
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Load and pivot the 2010 income CSV
# ---------------------------------------------------------------------------

def load_2010_income(csv_path: Path) -> pd.DataFrame:
    """Load and pivot 2010acs_all.csv into long format.

    Input columns: geoid, name, city_name, state, id_1, avghinc, hinc000..hinc200
    Output columns: geoid, label, block_estimate, block_total, group_label
    """
    df = pd.read_csv(csv_path, dtype=str, low_memory=False)
    df.columns = df.columns.str.lower().str.strip()

    # Keep only the hinc columns (not the _w weighted versions)
    hinc_cols = [c for c in df.columns if c.startswith("hinc") and not c.endswith("_w")]

    # Rename id_1 → id if present
    if "id_1" in df.columns:
        df = df.rename(columns={"id_1": "id"})

    keep_cols = ["geoid", "name", "city_name", "state", "id"] + hinc_cols
    keep_cols = [c for c in keep_cols if c in df.columns]
    df = df[keep_cols].copy()

    # Pivot to long
    df_long = df.melt(
        id_vars=[c for c in keep_cols if c not in hinc_cols],
        value_vars=hinc_cols,
        var_name="hinc_code",
        value_name="block_estimate",
    )

    df_long["block_estimate"] = pd.to_numeric(df_long["block_estimate"], errors="coerce").fillna(0).astype(int)
    df_long["label"] = df_long["hinc_code"].map(HINC_LABELS)
    df_long["group_label"] = "Household Income"

    # block_total: sum all hinc estimates per geoid
    df_long["block_total"] = df_long.groupby("geoid")["block_estimate"].transform("sum")

    return df_long


# ---------------------------------------------------------------------------
# Join with CBSA and compute aggregations
# ---------------------------------------------------------------------------

def join_with_cbsa(df: pd.DataFrame, cbsa_xwalk: pd.DataFrame, state_xwalk: pd.DataFrame) -> pd.DataFrame:
    """Join 2010 income data with a CBSA crosswalk and compute aggregations.

    The geoid in the 2010 CSV includes a prefix ('15000US...' or similar);
    the R script strips the first 7 characters to get the 12-digit block GEOID.
    """
    out = df.copy()

    # Strip leading prefix to get 12-character block group GEOID
    # The R script uses str_sub(geoid, 8, 19) which is 0-indexed → chars 7:19
    out["geoid"] = out["geoid"].astype(str).str.strip()
    # If longer than 12 chars, strip prefix
    mask = out["geoid"].str.len() > 12
    out.loc[mask, "geoid"] = out.loc[mask, "geoid"].str[-12:]

    out["county_fips"]  = out["geoid"].str[:5]
    out["tract"]        = out["geoid"].str[5:11]
    out["block_group"]  = out["geoid"].str[11:12]
    out["state_fips"]   = out["county_fips"].str[:2]

    # Join state info
    out = out.merge(state_xwalk[["state_fips", "state_name"]], on="state_fips", how="left")

    # Join CBSA
    out = out.merge(cbsa_xwalk, on="county_fips", how="left")
    out = out[out["cbsa_fips"].notna() & (out["cbsa_fips"] != "")].copy()

    # Aggregations
    out["block_total"]    = out.groupby(["geoid", "group_label"])["block_estimate"].transform("sum")
    out["county_estimate"] = out.groupby(["county_fips", "label"])["block_estimate"].transform("sum")
    out["county_total"]   = out.groupby(["county_fips", "group_label"])["block_estimate"].transform("sum")
    out["cbsa_estimate"]  = out.groupby(["cbsa_fips", "label"])["block_estimate"].transform("sum")
    out["cbsa_total"]     = out.groupby(["cbsa_fips", "group_label"])["block_estimate"].transform("sum")

    # Percentages
    out["block_pct"]  = out["block_estimate"]  / out["block_total"].replace(0, float("nan"))
    out["county_pct"] = out["county_estimate"] / out["county_total"].replace(0, float("nan"))
    out["cbsa_pct"]   = out["cbsa_estimate"]   / out["cbsa_total"].replace(0, float("nan"))

    for col in ["block_pct", "county_pct", "cbsa_pct"]:
        out[col] = out[col].fillna(0.0)

    # Rename for DKL compatibility
    out = out.rename(columns={"geoid": "block_fips", "state": "state_codes"})
    if "state_codes" not in out.columns:
        out["state_codes"] = ""

    # Add DKL-required columns with defaults
    out["variable"] = out["label"]  # used as the bin identifier
    out["variable_group"] = "B19001"

    # Ensure all required columns exist
    for col in ["county_name", "area_type", "central_outlying_county", "cbsa_title"]:
        if col not in out.columns:
            out[col] = ""

    cols = [
        "block_fips", "county_fips", "county_name", "cbsa_fips", "cbsa_title",
        "area_type", "central_outlying_county", "state_codes", "state_fips",
        "state_name", "variable", "variable_group", "group_label", "label",
        "block_pct", "block_estimate", "block_total",
        "county_pct", "county_estimate", "county_total",
        "cbsa_pct", "cbsa_estimate", "cbsa_total",
    ]
    for col in cols:
        if col not in out.columns:
            out[col] = None
    return out[cols].sort_values(["county_fips", "block_fips", "label"]).reset_index(drop=True)


# ---------------------------------------------------------------------------
# DKL wrapper for 2010 income data
# (uses the same calculate_dkl but grouped on group_label not variable_group)
# ---------------------------------------------------------------------------

def calc_dkl_income_2010(df: pd.DataFrame) -> pd.DataFrame:
    """Run DKL calculation for the 2010 income data.

    The 2010 CSV has a single group_label ('Household Income') and uses
    `label` as the bin identifier (not a coded variable string). We alias
    variable_group so the standard calculate_dkl() groupby keys work.
    """
    df = df.copy()
    df["variable_group"] = df["group_label"]  # normalise for calculate_dkl()
    return calculate_dkl(df)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Process 2010 income data and calculate DKL.")
    parser.add_argument(
        "--input-file",
        default=str(DATA_DIR / "dropbox" / "2010acs_all.csv"),
        help="Path to 2010acs_all.csv",
    )
    parser.add_argument(
        "--cbsa-years", nargs="+", type=int, default=[2020, 2009],
        help="CBSA crosswalk year(s) to use (default: 2020 and 2009).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    input_path = Path(args.input_file)
    if not input_path.exists():
        logger.error(
            "Input file not found: %s\n"
            "Place 2010acs_all.csv at data/dropbox/2010acs_all.csv "
            "or pass --input-file.",
            input_path,
        )
        sys.exit(1)

    out_dir = DATA_DIR / "acs5_block_2010_data"
    out_dir.mkdir(parents=True, exist_ok=True)
    state_xwalk = _build_state_xwalk()

    logger.info("Loading 2010 income data from %s …", input_path)
    df_long = load_2010_income(input_path)

    for cbsa_yr in args.cbsa_years:
        logger.info("Processing with CBSA year %d …", cbsa_yr)
        cbsa_xwalk = get_cbsa_xwalk(cbsa_yr)
        df_agg = join_with_cbsa(df_long, cbsa_xwalk, state_xwalk)
        df_dkl = calc_dkl_income_2010(df_agg)

        if cbsa_yr == 2020:
            out_path = out_dir / "dkl_income_10_blkgrp_all_states.parquet"
        else:
            out_path = out_dir / f"cbsa_{str(cbsa_yr)[2:]}_dkl_income_10_blkgrp_all_states.parquet"

        df_dkl.to_parquet(out_path, index=False)
        logger.info("Saved %s (%d rows)", out_path.name, len(df_dkl))
