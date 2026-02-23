"""
variable_maps.py
================
Maps conceptual variable categories (race, income, educ, empl) to
year-specific Census variable codes and human-readable labels.

Supported datasets:
  - ACS 5-year (2009–2023): B-tables (B03002, B19001, B15003, B23025)
  - 2010 Decennial SF1: P003/P004 (race only)
  - 2000 Decennial SF1: P003/P004 (race)
  - 2000 Decennial SF3: P052 (income), P037 (education), P043 (employment)

The income brackets differ across datasets and are preserved as-is so the
DKL function works identically regardless of year — no inflation adjustment.
"""

from __future__ import annotations
from typing import Dict, List, Tuple


# ---------------------------------------------------------------------------
# Type aliases
# ---------------------------------------------------------------------------
VarCode = str
Label = str
VarMap = Dict[VarCode, Label]           # {variable_code: label}
GroupedVars = Dict[str, List[VarCode]]  # {group_name: [codes]}


# ---------------------------------------------------------------------------
# ACS 5-year (2009–2023) — variable codes are stable across this range
# ---------------------------------------------------------------------------

# Race / Ethnicity — B03002
# Keep: total + 8 non-Hispanic races + Hispanic/Latino
# Drop: B03002_010 (two+ races, some other), _011 (two+ races, not listed),
#       _013–_021 (Hispanic sub-groups not needed)
ACS_RACE_VARS: VarMap = {
    "B03002_001": "Total",
    "B03002_003": "White alone",
    "B03002_004": "Black or African American alone",
    "B03002_005": "American Indian and Alaska Native alone",
    "B03002_006": "Asian alone",
    "B03002_007": "Native Hawaiian and Other Pacific Islander alone",
    "B03002_008": "Some other race alone",
    "B03002_009": "Two or more races",
    "B03002_012": "Hispanic or Latino (any race)",
}

# Household Income — B19001 (16 brackets)
ACS_INCOME_VARS: VarMap = {
    "B19001_001": "Total",
    "B19001_002": "Less than $10,000",
    "B19001_003": "$10,000 to $14,999",
    "B19001_004": "$15,000 to $19,999",
    "B19001_005": "$20,000 to $24,999",
    "B19001_006": "$25,000 to $29,999",
    "B19001_007": "$30,000 to $34,999",
    "B19001_008": "$35,000 to $39,999",
    "B19001_009": "$40,000 to $44,999",
    "B19001_010": "$45,000 to $49,999",
    "B19001_011": "$50,000 to $59,999",
    "B19001_012": "$60,000 to $74,999",
    "B19001_013": "$75,000 to $99,999",
    "B19001_014": "$100,000 to $124,999",
    "B19001_015": "$125,000 to $149,999",
    "B19001_016": "$150,000 to $199,999",
    "B19001_017": "$200,000 or more",
}

# Educational Attainment (25+) — B15003
ACS_EDUC_VARS: VarMap = {
    "B15003_001": "Total",
    "B15003_002": "No schooling completed",
    "B15003_003": "Nursery school",
    "B15003_004": "Kindergarten",
    "B15003_005": "1st grade",
    "B15003_006": "2nd grade",
    "B15003_007": "3rd grade",
    "B15003_008": "4th grade",
    "B15003_009": "5th grade",
    "B15003_010": "6th grade",
    "B15003_011": "7th grade",
    "B15003_012": "8th grade",
    "B15003_013": "9th grade",
    "B15003_014": "10th grade",
    "B15003_015": "11th grade",
    "B15003_016": "12th grade, no diploma",
    "B15003_017": "Regular high school diploma",
    "B15003_018": "GED or alternative credential",
    "B15003_019": "Some college, less than 1 year",
    "B15003_020": "Some college, 1 or more years, no degree",
    "B15003_021": "Associate's degree",
    "B15003_022": "Bachelor's degree",
    "B15003_023": "Master's degree",
    "B15003_024": "Professional school degree",
    "B15003_025": "Doctorate degree",
}

# Employment Status (16+) — B23025
ACS_EMPL_VARS: VarMap = {
    "B23025_001": "Total",
    "B23025_002": "In labor force",
    "B23025_003": "Civilian labor force",
    "B23025_004": "Employed",
    "B23025_005": "Unemployed",
    "B23025_006": "Armed Forces",
    "B23025_007": "Not in labor force",
}

# Human-readable group label per variable group prefix
ACS_GROUP_LABELS: Dict[str, str] = {
    "B03002": "Race/Ethnicity",
    "B19001": "Household Income",
    "B15003": "Education attainment",
    "B23025": "Employment",
}

# Totals to strip from each group (kept only for block_total denominator calc)
ACS_TOTALS: List[VarCode] = [
    "B03002_001", "B19001_001", "B15003_001", "B23025_001",
]


# ---------------------------------------------------------------------------
# 2010 Decennial Census — SF1 (race only)
# ---------------------------------------------------------------------------

# P003: Race alone — block group level
SF1_2010_RACE_VARS: VarMap = {
    "P003001": "Total",
    "P003002": "White alone",
    "P003003": "Black or African American alone",
    "P003004": "American Indian and Alaska Native alone",
    "P003005": "Asian alone",
    "P003006": "Native Hawaiian and Other Pacific Islander alone",
    "P003007": "Some other race alone",
    "P003008": "Two or more races",
}

# P004: Hispanic or Latino origin by race — block group level
SF1_2010_HISP_VARS: VarMap = {
    "P004001": "Total",
    "P004003": "Hispanic or Latino (any race)",
}

SF1_2010_GROUP_LABELS: Dict[str, str] = {
    "P003": "Race/Ethnicity",
    "P004": "Race/Ethnicity",
}


# ---------------------------------------------------------------------------
# 2000 Decennial Census — SF1 (race) + SF3 (income/educ/empl)
# ---------------------------------------------------------------------------

# SF1 — P003 / P004 (race)
SF1_2000_RACE_VARS: VarMap = {
    "P003001": "Total",
    "P003003": "White alone",
    "P003004": "Black or African American alone",
    "P003005": "American Indian and Alaska Native alone",
    "P003006": "Asian alone",
    "P003007": "Native Hawaiian and Other Pacific Islander alone",
    "P003008": "Some other race alone",
    "P003009": "Two or more races",
}

SF1_2000_HISP_VARS: VarMap = {
    "P004001": "Total",
    "P004002": "Hispanic or Latino (any race)",
}

# SF3 — P052 (income in 1999 dollars, 15 brackets)
# Note: 2000 SF3 uses 1999 dollar values; labels preserved as-is.
SF3_2000_INCOME_VARS: VarMap = {
    "P052001": "Total",
    "P052002": "Less than $10,000",
    "P052003": "$10,000 to $14,999",
    "P052004": "$15,000 to $19,999",
    "P052005": "$20,000 to $24,999",
    "P052006": "$25,000 to $29,999",
    "P052007": "$30,000 to $34,999",
    "P052008": "$35,000 to $39,999",
    "P052009": "$40,000 to $44,999",
    "P052010": "$45,000 to $49,999",
    "P052011": "$50,000 to $59,999",
    "P052012": "$60,000 to $74,999",
    "P052013": "$75,000 to $99,999",
    "P052014": "$100,000 to $124,999",
    "P052015": "$125,000 to $149,999",
    "P052016": "$150,000 to $199,999",
    "P052017": "$200,000 or more",
}

# SF3 — P037 (educational attainment 25+, combined sexes)
SF3_2000_EDUC_VARS: VarMap = {
    "P037001": "Total",
    "P037003": "No schooling completed",
    "P037004": "Nursery to 4th grade",
    "P037005": "5th and 6th grade",
    "P037006": "7th and 8th grade",
    "P037007": "9th grade",
    "P037008": "10th grade",
    "P037009": "11th grade",
    "P037010": "12th grade, no diploma",
    "P037011": "High school graduate (includes equivalency)",
    "P037012": "Some college, less than 1 year",
    "P037013": "Some college, 1 or more years, no degree",
    "P037014": "Associate degree",
    "P037015": "Bachelor's degree",
    "P037016": "Master's degree",
    "P037017": "Professional school degree",
    "P037018": "Doctorate degree",
    "P037019": "No schooling completed (female)",
    "P037020": "Nursery to 4th grade (female)",
    "P037021": "5th and 6th grade (female)",
    "P037022": "7th and 8th grade (female)",
    "P037023": "9th grade (female)",
    "P037024": "10th grade (female)",
    "P037025": "11th grade (female)",
    "P037026": "12th grade, no diploma (female)",
    "P037027": "High school graduate (includes equivalency) (female)",
    "P037028": "Some college, less than 1 year (female)",
    "P037029": "Some college, 1 or more years, no degree (female)",
    "P037030": "Associate degree (female)",
    "P037031": "Bachelor's degree (female)",
    "P037032": "Master's degree (female)",
    "P037033": "Professional school degree (female)",
    "P037034": "Doctorate degree (female)",
}

# SF3 — P043 (employment status 16+)
SF3_2000_EMPL_VARS: VarMap = {
    "P043001": "Total",
    "P043002": "In labor force",
    "P043003": "Civilian labor force: Employed (male)",
    "P043004": "Civilian labor force: Unemployed (male)",
    "P043005": "Armed Forces (male)",
    "P043006": "Not in labor force (male)",
    "P043007": "In labor force (female)",
    "P043008": "Civilian labor force: Employed (female)",
    "P043009": "Civilian labor force: Unemployed (female)",
    "P043010": "Armed Forces (female)",
    "P043011": "Not in labor force (female)",
}

SF3_2000_GROUP_LABELS: Dict[str, str] = {
    "P052": "Household Income",
    "P037": "Education attainment",
    "P043": "Employment",
}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_variable_map(year: int | str, dataset: str, var_group: str) -> Tuple[VarMap, str]:
    """Return (variable_code → label dict, group_label) for the given year/dataset/group.

    Parameters
    ----------
    year : int or str
        Data year integer (e.g. 2020) or special key '2010dec' / '2000dec'.
    dataset : str
        Census dataset string, e.g. 'acs5', 'sf1', 'sf3'.
    var_group : str
        One of 'race', 'income', 'educ', 'empl'.

    Returns
    -------
    (var_map, group_label) : tuple
        var_map  — dict mapping variable codes to human-readable labels
                   (totals *included* so the caller can derive block totals)
        group_label — string like "Race/Ethnicity"
    """
    key = str(year) if not isinstance(year, int) else year

    if dataset == "acs5":
        mapping = {
            "race":   (ACS_RACE_VARS,   "Race/Ethnicity"),
            "income": (ACS_INCOME_VARS, "Household Income"),
            "educ":   (ACS_EDUC_VARS,   "Education attainment"),
            "empl":   (ACS_EMPL_VARS,   "Employment"),
        }
        if var_group not in mapping:
            raise ValueError(f"Unknown var_group '{var_group}' for ACS 5-year.")
        return mapping[var_group]

    if key == "2010dec" and dataset == "sf1":
        if var_group == "race":
            combined = {**SF1_2010_RACE_VARS, **SF1_2010_HISP_VARS}
            return combined, "Race/Ethnicity"
        raise ValueError(f"2010 SF1 only supports 'race'; got '{var_group}'.")

    if key == "2000dec":
        if dataset == "sf1":
            if var_group == "race":
                combined = {**SF1_2000_RACE_VARS, **SF1_2000_HISP_VARS}
                return combined, "Race/Ethnicity"
            raise ValueError(f"2000 SF1 only supports 'race'; got '{var_group}'.")
        if dataset == "sf3":
            mapping = {
                "income": (SF3_2000_INCOME_VARS, "Household Income"),
                "educ":   (SF3_2000_EDUC_VARS,   "Education attainment"),
                "empl":   (SF3_2000_EMPL_VARS,   "Employment"),
            }
            if var_group not in mapping:
                raise ValueError(f"Unknown var_group '{var_group}' for 2000 SF3.")
            return mapping[var_group]

    raise ValueError(f"Unsupported year/dataset combination: year={year}, dataset={dataset}.")


def get_acs_totals() -> List[VarCode]:
    """Return list of ACS total variable codes (one per group) to identify denominators."""
    return list(ACS_TOTALS)


def get_variable_group_prefix(var_code: str) -> str:
    """Extract the group prefix from a variable code (e.g. 'B19001_014' → 'B19001')."""
    return var_code.split("_")[0] if "_" in var_code else var_code[:5]
