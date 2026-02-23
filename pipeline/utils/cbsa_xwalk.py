"""
cbsa_xwalk.py
=============
Downloads the appropriate CBSA (Core-Based Statistical Area) delineation
file from the Census Bureau and returns a standardised DataFrame.

Output schema:
    county_fips              | cbsa_fips | cbsa_title | area_type | central_outlying_county
    12-digit or 5-digit FIPS | 5-digit   | str        | str       | str

Supported year formats:
    2020 — list1_2020.xls  (rows 3–1919)
    2015 — list1.xls        (rows 3–1919)
    2009 — list3.xls        (rows 4–1866, different column layout)
    2003 — earliest CBSA file (rows 3–N)
"""

from __future__ import annotations

import io
import logging
import os
import tempfile
from pathlib import Path
from typing import Optional

import pandas as pd
import requests

logger = logging.getLogger(__name__)

# Cache directory for downloaded crosswalk files
_CACHE_DIR = Path(tempfile.gettempdir()) / "dkl_cbsa_cache"
_CACHE_DIR.mkdir(exist_ok=True)

# Known xwalk URLs mapped by nominal "year format" key
_XWALK_URLS = {
    2020: "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls",
    2015: "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2015/delineation-files/list1.xls",
    2009: "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2009/historical-delineation-files/list3.xls",
    2003: "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2003/historical-delineation-files/0312cbsas-csas.xls",
}


def _download_file(url: str) -> bytes:
    """Download a URL to bytes, using a local file cache."""
    cache_path = _CACHE_DIR / Path(url).name
    if cache_path.exists():
        logger.debug("Using cached file: %s", cache_path)
        return cache_path.read_bytes()
    logger.info("Downloading CBSA crosswalk from %s …", url)
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    cache_path.write_bytes(response.content)
    return response.content


def _clean_col_names(df: pd.DataFrame) -> pd.DataFrame:
    """Normalise column names: lower-case, spaces/dots/slashes → underscore."""
    df.columns = (
        df.columns.str.strip()
        .str.lower()
        .str.replace(r"[\s./]+", "_", regex=True)
        .str.replace(r"_+", "_", regex=True)
        .str.strip("_")
    )
    return df


def _parse_2009(raw: bytes) -> pd.DataFrame:
    """Parse the 2009 list3.xls format (rows 4–1866, single FIPS column)."""
    df = pd.read_excel(
        io.BytesIO(raw),
        sheet_name=0,
        skiprows=3,       # skip rows 1–3 (header at row 4)
        nrows=1863,       # rows 4–1866
        engine="xlrd",
        dtype=str,
    )
    df = _clean_col_names(df)

    # In the 2009 file there is a single 'fips' column (5-digit state+county)
    df["fips"] = df["fips"].fillna("").str.strip().str.zfill(5)
    df["fips_state_code"] = df["fips"].str[:2]
    df["fips_county_code"] = df["fips"].str[2:]
    df["county_fips"] = df["fips_state_code"].str.zfill(2) + df["fips_county_code"].str.zfill(3)

    df = df.rename(columns={
        "cbsa_code": "cbsa_fips",
        "level_of_cbsa": "area_type",
        "county_status": "central_outlying_county",
    })

    return df[["county_fips", "cbsa_fips", "cbsa_title", "area_type", "central_outlying_county"]].copy()


def _parse_standard(raw: bytes) -> pd.DataFrame:
    """Parse 2015/2020/2003 list*.xls format (rows 3–1919, split FIPS columns)."""
    df = pd.read_excel(
        io.BytesIO(raw),
        sheet_name=0,
        skiprows=2,       # skip rows 1–2 (header at row 3)
        nrows=1917,       # rows 3–1919
        engine="xlrd",
        dtype=str,
    )
    df = _clean_col_names(df)

    # Normalise FIPS columns
    state_col = next(
        (c for c in df.columns if "fips_state" in c or c == "state_fips"),
        None,
    )
    county_col = next(
        (c for c in df.columns if "fips_county" in c or c == "county_fips_code"),
        None,
    )
    if state_col is None or county_col is None:
        raise ValueError(
            f"Could not find state/county FIPS columns. Found: {list(df.columns)}"
        )

    df[state_col] = df[state_col].fillna("").str.strip().str.zfill(2)
    df[county_col] = df[county_col].fillna("").str.strip().str.zfill(3)
    df["county_fips"] = df[state_col] + df[county_col]

    # Rename to standard names
    rename_map = {}
    for col in df.columns:
        if "cbsa_code" in col:
            rename_map[col] = "cbsa_fips"
        elif col in ("metropolitan_micropolitan_statistical_area", "cbsa_type"):
            rename_map[col] = "area_type"
        elif "cbsa_title" not in col and "cbsa_name" in col:
            rename_map[col] = "cbsa_title"
    df = df.rename(columns=rename_map)

    # Ensure central_outlying_county exists
    if "central_outlying_county" not in df.columns:
        outlying_col = next(
            (c for c in df.columns if "outlying" in c or "central" in c),
            None,
        )
        if outlying_col:
            df = df.rename(columns={outlying_col: "central_outlying_county"})
        else:
            df["central_outlying_county"] = ""

    required = ["county_fips", "cbsa_fips", "cbsa_title", "area_type", "central_outlying_county"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Missing columns after parsing: {missing}. Available: {list(df.columns)}")

    return df[required].copy()


def get_cbsa_xwalk(
    year_format: int,
    *,
    url: Optional[str] = None,
) -> pd.DataFrame:
    """Download and return the CBSA crosswalk for the given year format.

    Parameters
    ----------
    year_format : int
        One of 2020, 2015, 2009, 2003 — selects the right Census delineation
        file and parsing logic.
    url : str, optional
        Override the default URL for the given year_format.

    Returns
    -------
    pd.DataFrame
        Columns: county_fips (5-digit str), cbsa_fips (5-digit str),
                 cbsa_title, area_type, central_outlying_county.
    """
    if url is None:
        if year_format not in _XWALK_URLS:
            raise ValueError(
                f"Unsupported year_format {year_format}. "
                f"Choose from {sorted(_XWALK_URLS)}."
            )
        url = _XWALK_URLS[year_format]

    raw = _download_file(url)

    if year_format == 2009:
        df = _parse_2009(raw)
    else:
        df = _parse_standard(raw)

    # Drop rows with no CBSA (non-metro counties)
    df = df[df["cbsa_fips"].notna() & (df["cbsa_fips"].str.strip() != "")].copy()

    # Ensure string types and clean whitespace
    for col in ["county_fips", "cbsa_fips", "cbsa_title", "area_type", "central_outlying_county"]:
        df[col] = df[col].fillna("").astype(str).str.strip()

    df = df.drop_duplicates(subset=["county_fips"]).reset_index(drop=True)
    logger.info("Loaded CBSA crosswalk (year=%d): %d metro counties.", year_format, len(df))
    return df
