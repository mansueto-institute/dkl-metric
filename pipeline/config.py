"""
DKL Pipeline Configuration
===========================
Paths, Census API key, year × dataset config, and state/city filter lists.

NOTE ON 1990 DATA
-----------------
Block group data for 1990 is not available via the Census Bureau API.
Due to tract-number errors in the API, 1990 block group data was removed.
Users who need 1990 block group data should use NHGIS (https://nhgis.org),
which provides historical Census microdata including 1990 STF files.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# Load .env for CENSUS_API_KEY
load_dotenv(Path(__file__).parent / ".env")

# Root of this pipeline directory
PIPELINE_DIR = Path(__file__).parent

# Data directory — mirrors the E:/ drive layout from R scripts.
# Override by setting DATA_DIR in .env or as an environment variable.
DATA_DIR = Path(os.getenv("DATA_DIR", PIPELINE_DIR / "data"))

# Census API key — set CENSUS_API_KEY in your .env file.
# Obtain a key at: https://api.census.gov/data/key_signup.html
CENSUS_API_KEY = os.getenv("CENSUS_API_KEY", "")

if not CENSUS_API_KEY:
    import warnings
    warnings.warn(
        "CENSUS_API_KEY is not set. Add it to pipeline/.env as:\n"
        "  CENSUS_API_KEY=your_key_here\n"
        "Get a key at https://api.census.gov/data/key_signup.html"
    )

# ---------------------------------------------------------------------------
# Year × dataset configuration
# ---------------------------------------------------------------------------
# Each entry maps a data year to:
#   dataset        : Census API dataset identifier
#   cbsa_xwalk_url : URL to the CBSA delineation Excel file for that year
#   available_vars : which variable groups are retrievable for that year/dataset
#
# Notes:
#   - 2009–2023 ACS 5-year: full set of race/income/educ/empl variables (B-tables)
#   - 2010 Decennial SF1: race only (P003/P004 tables)
#   - 2000 Decennial SF1+SF3: race (SF1) + income/educ/empl (SF3)
#   - 1990: NOT AVAILABLE at block group via Census API — use NHGIS instead

YEAR_CONFIGS = {
    # --- ACS 5-year (2009–2023) ---
    2009: {
        "dataset": "acs5",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2009/historical-delineation-files/list3.xls",
        "cbsa_xwalk_year_format": 2009,
        "available_vars": ["race", "income", "educ", "empl"],
    },
    2010: {
        "dataset": "acs5",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2009/historical-delineation-files/list3.xls",
        "cbsa_xwalk_year_format": 2009,
        "available_vars": ["race", "income", "educ", "empl"],
    },
    2015: {
        "dataset": "acs5",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2015/delineation-files/list1.xls",
        "cbsa_xwalk_year_format": 2015,
        "available_vars": ["race", "income", "educ", "empl"],
    },
    2020: {
        "dataset": "acs5",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls",
        "cbsa_xwalk_year_format": 2020,
        "available_vars": ["race", "income", "educ", "empl"],
    },
    2021: {
        "dataset": "acs5",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls",
        "cbsa_xwalk_year_format": 2020,
        "available_vars": ["race", "income", "educ", "empl"],
    },
    2022: {
        "dataset": "acs5",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls",
        "cbsa_xwalk_year_format": 2020,
        "available_vars": ["race", "income", "educ", "empl"],
    },
    2023: {
        "dataset": "acs5",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls",
        "cbsa_xwalk_year_format": 2020,
        "available_vars": ["race", "income", "educ", "empl"],
    },
    # --- 2010 Decennial SF1 ---
    # Race only; income/education/employment require the ACS 5-year 2010 endpoint (above).
    "2010dec": {
        "dataset": "sf1",
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2009/historical-delineation-files/list3.xls",
        "cbsa_xwalk_year_format": 2009,
        "available_vars": ["race"],
    },
    # --- 2000 Decennial SF1 + SF3 ---
    # SF1 for race; SF3 for income (1999 dollars, 15 brackets), educ, empl.
    # Income brackets in 2000 SF3 differ from ACS — labels are preserved as-is
    # so DKL is computed on original categories (not inflation-adjusted).
    "2000dec": {
        "dataset": "sf1",          # primary; sf3 fetched separately for income/educ/empl
        "cbsa_xwalk_url": "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2003/historical-delineation-files/0312cbsas-csas.xls",
        "cbsa_xwalk_year_format": 2003,
        "available_vars": ["race", "income", "educ", "empl"],
    },
}

# Shapefile boundary year to use for a given data year
# (2015 boundary for 2009–2019; 2020 boundary for 2020+)
SHAPEFILE_YEAR = {yr: (2020 if (isinstance(yr, int) and yr >= 2020) else 2015)
                  for yr in YEAR_CONFIGS}

# ---------------------------------------------------------------------------
# State codes and FIPS
# ---------------------------------------------------------------------------

STATE_CODES = [
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
]

# ---------------------------------------------------------------------------
# Cities / metros for city-specific notebooks (7 & 8)
# ---------------------------------------------------------------------------

CITIES = [
    "Atlanta-Sandy Springs-Alpharetta, GA",
    "Boston-Cambridge-Newton, MA-NH",
    "Chicago-Naperville-Elgin, IL-IN-WI",
    "Dallas-Fort Worth-Arlington, TX",
    "Detroit-Warren-Dearborn, MI",
    "Houston-The Woodlands-Sugar Land, TX",
    "Los Angeles-Long Beach-Anaheim, CA",
    "Miami-Fort Lauderdale-Pompano Beach, FL",
    "Minneapolis-St. Paul-Bloomington, MN-WI",
    "New York-Newark-Jersey City, NY-NJ-PA",
    "Philadelphia-Camden-Wilmington, PA-NJ-DE-MD",
    "Phoenix-Mesa-Chandler, AZ",
    "Seattle-Tacoma-Bellevue, WA",
    "Washington-Arlington-Alexandria, DC-VA-MD-WV",
]
