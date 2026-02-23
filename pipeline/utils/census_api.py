"""
census_api.py
=============
Unified wrapper around the `census` Python package for fetching ACS and
Decennial Census data at the block-group level.

Output schema (standardised DataFrame):
    geoid     | variable | estimate | state
    ----------|----------|----------|-------
    150010001 | B19001_002 | 42      | IL

This matches the raw parquet schema expected by 1_clean.py.
"""

from __future__ import annotations

import logging
from typing import List, Optional

import pandas as pd
from census import Census

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _make_client(api_key: str) -> Census:
    return Census(api_key)


def _fips_for_state(state: str) -> str:
    """Convert a 2-letter state abbreviation to its 2-digit FIPS code.

    Uses the built-in us library if available, otherwise falls back to a
    hard-coded lookup table.
    """
    try:
        import us
        s = us.states.lookup(state)
        if s is None:
            raise ValueError(f"Unknown state abbreviation: {state}")
        return s.fips
    except ImportError:
        _FIPS = {
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
        if state not in _FIPS:
            raise ValueError(f"Unknown state abbreviation: {state}")
        return _FIPS[state]


def _build_geoid_acs(row: dict, state_fips: str) -> str:
    """Build a 12-digit block-group GEOID from an ACS API response row."""
    # ACS block group response contains: state, county, tract, block group
    state   = str(row.get("state", state_fips)).zfill(2)
    county  = str(row.get("county", "")).zfill(3)
    tract   = str(row.get("tract", "")).zfill(6)
    bg      = str(row.get("block group", "")).zfill(1)
    return f"{state}{county}{tract}{bg}"


def _build_geoid_decennial(row: dict, state_fips: str) -> str:
    """Build a 12-digit block-group GEOID from a Decennial Census API row."""
    state   = str(row.get("state", state_fips)).zfill(2)
    county  = str(row.get("county", "")).zfill(3)
    tract   = str(row.get("tract", "")).zfill(6)
    bg      = str(row.get("block group", "")).zfill(1)
    return f"{state}{county}{tract}{bg}"


def _chunk_variables(variables: List[str], chunk_size: int = 45) -> List[List[str]]:
    """Split a variable list into chunks; Census API has a ~50-variable limit."""
    return [variables[i : i + chunk_size] for i in range(0, len(variables), chunk_size)]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def fetch_block_group_data(
    year: int,
    dataset: str,
    variables: List[str],
    state: str,
    api_key: str,
    *,
    var_label_map: Optional[dict] = None,
) -> pd.DataFrame:
    """Fetch block-group level Census data for a single state.

    Parameters
    ----------
    year : int
        Data year (e.g. 2020).
    dataset : str
        Census dataset: 'acs5', 'sf1', or 'sf3'.
    variables : list of str
        Census variable codes to fetch.
    state : str
        Two-letter state abbreviation (e.g. 'IL').
    api_key : str
        Census API key.
    var_label_map : dict, optional
        {variable_code: label} mapping.  If provided, a 'label' column is
        added to the output DataFrame.

    Returns
    -------
    pd.DataFrame
        Columns: geoid, variable, estimate, state
        (plus 'label' if var_label_map is supplied).
    """
    client = _make_client(api_key)
    state_fips = _fips_for_state(state)

    # Select the right Census dataset object
    if dataset == "acs5":
        ds = client.acs5
        _build_geoid = _build_geoid_acs
    elif dataset in ("sf1", "sf3"):
        ds = getattr(client, dataset)
        _build_geoid = _build_geoid_decennial
    else:
        raise ValueError(f"Unsupported dataset '{dataset}'. Use 'acs5', 'sf1', or 'sf3'.")

    all_records: list[dict] = []

    # ACS variables need an 'E' suffix for estimates (e.g. B19001_001 → B19001_001E).
    # Decennial SF1/SF3 variables do not use a suffix.
    def _api_code(var: str) -> str:
        if dataset == "acs5" and not var.endswith("E") and not var.endswith("M"):
            return var + "E"
        return var

    def _base_code(api_var: str) -> str:
        if dataset == "acs5" and api_var.endswith("E"):
            return api_var[:-1]
        return api_var

    for chunk in _chunk_variables(variables):
        api_chunk = [_api_code(v) for v in chunk]
        logger.debug("Fetching %d vars for %s %s %s …", len(chunk), dataset, year, state)
        rows = ds.state_county_blockgroup(
            fields=["NAME"] + api_chunk,
            state_fips=state_fips,
            county_fips=Census.ALL,
            blockgroup=Census.ALL,
            tract=Census.ALL,
            year=year,
        )
        if rows is None:
            logger.warning("No data returned for %s %s %s", dataset, year, state)
            continue
        for row in rows:
            geoid = _build_geoid(row, state_fips)
            for api_var, var in zip(api_chunk, chunk):
                raw = row.get(api_var)
                try:
                    estimate = int(raw) if raw is not None and raw != "" else None
                except (ValueError, TypeError):
                    estimate = None
                record: dict = {
                    "geoid": geoid,
                    "variable": var,   # always store the base code (no E suffix)
                    "estimate": estimate,
                    "state": state,
                }
                if var_label_map is not None:
                    record["label"] = var_label_map.get(var, var)
                all_records.append(record)

    if not all_records:
        return pd.DataFrame(columns=["geoid", "variable", "estimate", "state"])

    df = pd.DataFrame(all_records)
    df["estimate"] = pd.to_numeric(df["estimate"], errors="coerce").astype("Int64")
    return df


def fetch_all_states(
    year: int,
    dataset: str,
    variables: List[str],
    state_codes: List[str],
    api_key: str,
    *,
    var_label_map: Optional[dict] = None,
    show_progress: bool = True,
) -> pd.DataFrame:
    """Fetch block-group data for all states and concatenate.

    Parameters
    ----------
    year, dataset, variables, api_key : see fetch_block_group_data
    state_codes : list of str
        Two-letter state abbreviations.
    var_label_map : dict, optional
    show_progress : bool
        Show a tqdm progress bar.

    Returns
    -------
    pd.DataFrame
    """
    try:
        from tqdm import tqdm
        iterator = tqdm(state_codes, desc=f"{dataset} {year}", unit="state") if show_progress else state_codes
    except ImportError:
        iterator = state_codes

    frames: list[pd.DataFrame] = []
    for state in iterator:
        try:
            df = fetch_block_group_data(
                year=year,
                dataset=dataset,
                variables=variables,
                state=state,
                api_key=api_key,
                var_label_map=var_label_map,
            )
            frames.append(df)
        except Exception as exc:
            logger.error("Failed to fetch %s %s %s: %s", dataset, year, state, exc)

    if not frames:
        return pd.DataFrame(columns=["geoid", "variable", "estimate", "state"])
    return pd.concat(frames, ignore_index=True)
