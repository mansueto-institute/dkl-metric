"""
dkl.py
======
Core DKL (Kullback-Leibler divergence) calculation functions.

Direct translation of calculate_dkl() from helper_functions.R and
get_mutual_info_by_metro() from 4_get_mutual_info_summaries.R.

All operations are vectorised with pandas/numpy — no Python loops over rows.

Expected input schema for calculate_dkl()
------------------------------------------
The DataFrame must contain the following columns (produced by 1_clean.py):

    block_fips          str     12-digit block group GEOID
    county_fips         str     5-digit county FIPS
    cbsa_fips           str     5-digit CBSA FIPS
    variable            str     Census variable code (e.g. 'B19001_002')
    variable_group      str     Group prefix (e.g. 'B19001')
    label               str     Human-readable label
    group_label         str     Category name ('Household Income', etc.)
    block_estimate      int     Raw count for this variable in this block group
    block_total         int     Total for this variable_group in this block group
    cbsa_estimate       int     Total for this variable across the whole CBSA
    cbsa_total          int     Total for this variable_group across the whole CBSA

DKL formula (log base 2):
    p_ni      = block_total / cbsa_total          P(block i in MSA)
    p_ni_yj   = block_estimate / cbsa_estimate    P(block i | bin j)
    p_yj      = cbsa_estimate / cbsa_total        P(bin j for everyone in MSA)
    p_yj_ni   = block_estimate / block_total      P(bin j | block i)

    dkl_log_i = log2(p_yj_ni / p_yj)
    dkl_log_j = log2(p_ni_yj / p_ni)

    dkl_block_j = p_yj_ni * dkl_log_i   (per-bin contribution to block DKL)
    dkl_bin_i   = p_ni_yj * dkl_log_j   (per-block contribution to bin DKL)

    dkl_block[i] = Σ_j dkl_block_j   grouped by (variable_group, block_fips)
    dkl_bin[j]   = Σ_i dkl_bin_i     grouped by (variable_group, cbsa_fips, variable)

Mutual information:
    MI(cbsa) = Σ_i p_ni * dkl_block[i]   population-weighted mean of block DKLs
"""

from __future__ import annotations

import numpy as np
import pandas as pd


def calculate_dkl(df: pd.DataFrame) -> pd.DataFrame:
    """Calculate one-way DKL for each block group and bin.

    Parameters
    ----------
    df : pd.DataFrame
        Cleaned block-group data from 1_clean.py (see module docstring for
        required columns).

    Returns
    -------
    pd.DataFrame
        Input DataFrame with additional columns:
            p_ni, p_ni_yj, p_yj, p_yj_ni,
            dkl_log_i, dkl_log_j,
            dkl_block_j, dkl_bin_i,
            dkl_block, dkl_bin
    """
    out = df.copy()

    # Safely cast to float to avoid integer division edge cases
    block_estimate = out["block_estimate"].astype(float)
    block_total    = out["block_total"].astype(float)
    cbsa_estimate  = out["cbsa_estimate"].astype(float)
    cbsa_total     = out["cbsa_total"].astype(float)

    # Probability components — 0/0 → 0 via np.where masking
    out["p_ni"]    = np.where(cbsa_total  > 0, block_total    / cbsa_total,  0.0)
    out["p_ni_yj"] = np.where(cbsa_estimate > 0, block_estimate / cbsa_estimate, 0.0)
    out["p_yj"]    = np.where(cbsa_total  > 0, cbsa_estimate  / cbsa_total,  0.0)
    out["p_yj_ni"] = np.where(block_total > 0, block_estimate / block_total, 0.0)

    # Log ratios — set to 0 wherever argument would be 0, -inf, or nan
    # (matches R's replace(is.nan/is.infinite, 0) behaviour)
    ratio_i = np.where(out["p_yj"] > 0, out["p_yj_ni"] / out["p_yj"], 0.0)
    ratio_j = np.where(out["p_ni"] > 0, out["p_ni_yj"] / out["p_ni"], 0.0)

    with np.errstate(divide="ignore", invalid="ignore"):
        log_i = np.log2(ratio_i, where=(ratio_i > 0), out=np.zeros_like(ratio_i, dtype=float))
        log_j = np.log2(ratio_j, where=(ratio_j > 0), out=np.zeros_like(ratio_j, dtype=float))

    out["dkl_log_i"] = np.where(np.isfinite(log_i), log_i, 0.0)
    out["dkl_log_j"] = np.where(np.isfinite(log_j), log_j, 0.0)

    # Per-row components
    out["dkl_block_j"] = out["p_yj_ni"] * out["dkl_log_i"]
    out["dkl_bin_i"]   = out["p_ni_yj"] * out["dkl_log_j"]

    # Aggregate dkl_block: sum dkl_block_j over all bins for each block
    out["dkl_block"] = out.groupby(["variable_group", "block_fips"])["dkl_block_j"].transform("sum")

    # Aggregate dkl_bin: sum dkl_bin_i over all blocks for each (cbsa, variable) bin
    out["dkl_bin"] = out.groupby(["variable_group", "cbsa_fips", "variable"])["dkl_bin_i"].transform("sum")

    return out


def get_mutual_info(dkl_df: pd.DataFrame) -> pd.DataFrame:
    """Calculate mutual information (MI) at the CBSA level.

    MI(cbsa) = population-weighted mean of dkl_block, where weights are p_ni
    (the block's share of the CBSA total population for that variable group).

    This is equivalent to Σ_i p_ni * dkl_block[i].

    Parameters
    ----------
    dkl_df : pd.DataFrame
        Output of calculate_dkl().  Must contain:
            block_fips, variable_group, group_label, block_total,
            dkl_block, p_ni, cbsa_title, cbsa_total, state_codes.

    Returns
    -------
    pd.DataFrame
        One row per (cbsa_title, group_label) with columns:
            cbsa_title, state_codes, group_label, avg_dkl_cbsa_pop
    """
    # Deduplicate to one row per (block_fips, variable_group)
    block_level = (
        dkl_df[["block_fips", "variable_group", "group_label",
                 "block_total", "dkl_block", "p_ni",
                 "cbsa_title", "cbsa_total", "state_codes"]]
        .drop_duplicates(subset=["block_fips", "variable_group"])
        .copy()
    )

    def _weighted_mean(group: pd.DataFrame) -> float:
        weights = group["p_ni"]
        total_weight = weights.sum()
        if total_weight == 0:
            return 0.0
        return (group["dkl_block"] * weights).sum() / total_weight

    mi = (
        block_level
        .groupby(["cbsa_title", "state_codes", "group_label"])
        .apply(_weighted_mean, include_groups=False)
        .reset_index(name="avg_dkl_cbsa_pop")
    )

    return mi
