"""
5_shapefiles.py
===============
Download Census TIGER block-group boundary files (GeoJSON) for all 50
US states and both boundary vintages (2015 and 2020).

Mirrors: one-way-dkl/all_states_block/5_download_shapefiles.R

The R script used the `tigris` package; here we call the Census TIGER/Web
cartographic boundary API directly with `requests`.

API endpoint template:
    https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/
        tigerWMS_ACS{year}/MapServer/{layer}/query?
        where=STATE={fips}&outFields=*&f=geojson

For block groups the layer ID is:
    - 2020 vintage: layer 10 in TIGERweb ACS2020
    - 2015 vintage: layer 10 in TIGERweb ACS2016 (closest available)

Alternatively, we use the Census cartographic boundary file download:
    https://www2.census.gov/geo/tiger/GENZ{year}/shp/cb_{year}_{fips}_bg_500k.zip

Usage
-----
    python 5_shapefiles.py [--years 2015 2020] [--states IL TX ...]

Output files
------------
    data/shapefiles/usa_block_groups_{year}.geojson   (all states combined)
"""

from __future__ import annotations

import io
import logging
import sys
import zipfile
from pathlib import Path

import geopandas as gpd
import pandas as pd
import requests
from tqdm import tqdm

sys.path.insert(0, str(Path(__file__).parent))

import argparse
from config import DATA_DIR, STATE_CODES

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# State FIPS lookup
# ---------------------------------------------------------------------------

STATE_FIPS = {
    "AL": "01", "AK": "02", "AZ": "04", "AR": "05", "CA": "06",
    "CO": "08", "CT": "09", "DE": "10", "FL": "12", "GA": "13",
    "HI": "15", "ID": "16", "IL": "17", "IN": "18", "IA": "19",
    "KS": "20", "KY": "21", "LA": "22", "ME": "23", "MD": "24",
    "MA": "25", "MI": "26", "MN": "27", "MS": "28", "MO": "29",
    "MT": "30", "NE": "31", "NV": "32", "NH": "33", "NJ": "34",
    "NM": "35", "NY": "36", "NC": "37", "ND": "38", "OH": "39",
    "OK": "40", "OR": "41", "PA": "42", "RI": "44", "SC": "45",
    "SD": "46", "TN": "47", "TX": "48", "UT": "49", "VT": "50",
    "VA": "51", "WA": "53", "WV": "54", "WI": "55", "WY": "56",
    "DC": "11",
}


# ---------------------------------------------------------------------------
# Download helpers
# ---------------------------------------------------------------------------

def _fetch_state_block_groups(state_fips: str, year: int) -> gpd.GeoDataFrame:
    """Download cartographic block group boundaries for one state.

    Uses the Census Bureau's GENZ cartographic boundary ZIP files.
    URL: https://www2.census.gov/geo/tiger/GENZ{year}/shp/cb_{year}_{fips}_bg_500k.zip
    """
    url = (
        f"https://www2.census.gov/geo/tiger/GENZ{year}/shp/"
        f"cb_{year}_{state_fips}_bg_500k.zip"
    )
    logger.debug("Fetching %s", url)
    resp = requests.get(url, timeout=120)
    resp.raise_for_status()

    with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
        # Write all files to a temp directory and read the shapefile
        import tempfile, os
        with tempfile.TemporaryDirectory() as tmpdir:
            zf.extractall(tmpdir)
            shp_files = [f for f in os.listdir(tmpdir) if f.endswith(".shp")]
            if not shp_files:
                raise FileNotFoundError(f"No .shp file found in {url}")
            gdf = gpd.read_file(os.path.join(tmpdir, shp_files[0]))

    return gdf


def _fetch_state_tracts(state_fips: str, year: int) -> gpd.GeoDataFrame:
    """Download cartographic tract boundaries for one state.

    URL: https://www2.census.gov/geo/tiger/GENZ{year}/shp/cb_{year}_{fips}_tract_500k.zip
    """
    url = (
        f"https://www2.census.gov/geo/tiger/GENZ{year}/shp/"
        f"cb_{year}_{state_fips}_tract_500k.zip"
    )
    logger.debug("Fetching %s", url)
    resp = requests.get(url, timeout=120)
    resp.raise_for_status()

    with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
        import tempfile, os
        with tempfile.TemporaryDirectory() as tmpdir:
            zf.extractall(tmpdir)
            shp_files = [f for f in os.listdir(tmpdir) if f.endswith(".shp")]
            if not shp_files:
                raise FileNotFoundError(f"No .shp file found in {url}")
            gdf = gpd.read_file(os.path.join(tmpdir, shp_files[0]))

    return gdf


def download_shapefiles_for_year(year: int, state_codes: list[str]) -> gpd.GeoDataFrame:
    """Download and concatenate block-group shapefiles for all states."""
    gdfs: list[gpd.GeoDataFrame] = []
    errors: list[str] = []

    for code in tqdm(state_codes, desc=f"Shapefiles {year}", unit="state"):
        fips = STATE_FIPS.get(code)
        if fips is None:
            logger.warning("Unknown state code: %s", code)
            continue
        try:
            gdf = _fetch_state_block_groups(fips, year)
            gdfs.append(gdf)
        except Exception as exc:
            logger.error("Failed %s %d: %s", code, year, exc)
            errors.append(code)

    if errors:
        logger.warning("Failed to download shapefiles for: %s", errors)

    if not gdfs:
        raise RuntimeError(f"No shapefiles downloaded for year {year}.")

    combined = pd.concat(gdfs, ignore_index=True)
    return gpd.GeoDataFrame(combined, geometry="geometry", crs="EPSG:4326")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def download_tracts_for_year(year: int, state_codes: list[str]) -> gpd.GeoDataFrame:
    """Download and concatenate tract shapefiles for all states."""
    gdfs: list[gpd.GeoDataFrame] = []
    errors: list[str] = []

    for code in tqdm(state_codes, desc=f"Tract shapefiles {year}", unit="state"):
        fips = STATE_FIPS.get(code)
        if fips is None:
            logger.warning("Unknown state code: %s", code)
            continue
        try:
            gdf = _fetch_state_tracts(fips, year)
            gdfs.append(gdf)
        except Exception as exc:
            logger.error("Failed %s %d: %s", code, year, exc)
            errors.append(code)

    if errors:
        logger.warning("Failed to download tract shapefiles for: %s", errors)

    if not gdfs:
        raise RuntimeError(f"No tract shapefiles downloaded for year {year}.")

    combined = pd.concat(gdfs, ignore_index=True)
    return gpd.GeoDataFrame(combined, geometry="geometry", crs="EPSG:4326")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download Census boundary shapefiles.")
    parser.add_argument("--years", nargs="+", type=int, default=[2015, 2020])
    parser.add_argument("--states", nargs="+", default=STATE_CODES)
    parser.add_argument(
        "--geo", default="blockgroup", choices=["blockgroup", "tract"],
        help="Geographic level: blockgroup or tract (default: blockgroup).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    out_dir = DATA_DIR / "shapefiles"
    out_dir.mkdir(parents=True, exist_ok=True)

    for year in args.years:
        if args.geo == "tract":
            out_path = out_dir / f"usa_tracts_{year}.geojson"
            if out_path.exists():
                logger.info("Already exists, skipping: %s", out_path.name)
                continue
            logger.info("Downloading tract shapefiles for %d …", year)
            gdf = download_tracts_for_year(year, args.states)
        else:
            out_path = out_dir / f"usa_block_groups_{year}.geojson"
            if out_path.exists():
                logger.info("Already exists, skipping: %s", out_path.name)
                continue
            logger.info("Downloading block group shapefiles for %d …", year)
            gdf = download_shapefiles_for_year(year, args.states)

        gdf.to_file(out_path, driver="GeoJSON")
        logger.info("Saved %s (%d features)", out_path.name, len(gdf))
