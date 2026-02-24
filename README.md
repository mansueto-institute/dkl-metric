# DKL Spatial Selection

This repository contains code to calculate a one-way Kullback-Leibler (DKL) divergence metric for spatial selection — a measure of how unevenly demographic groups are distributed across block groups within a metropolitan area — and to aggregate it to a mutual information (MI) score at the MSA level.

The metric is described in the paper "Decoding the city: multiscale spatial information
in urban income distributions"  (https://arxiv.org/abs/2509.22954). It is generalized here to race/ethnicity, household income, educational attainment, and employment status at the Census block group level for all MSAs in the United States, for 2015 and 2020.

---

## Python Pipeline (`pipeline/`)

The primary codebase is a full Python pipeline that downloads Census data via the Census Bureau API, computes DKL and mutual information, and produces charts and maps.

### Requirements

```bash
cd pipeline
pip install -r requirements.txt
```

Create a `.env` file in `pipeline/` with your Census API key (obtain one free at https://api.census.gov/data/key_signup.html):

```
CENSUS_API_KEY=your_key_here
```

### Pipeline Steps

| Script | Description |
|--------|-------------|
| `0_download.py` | Download ACS 5-year block group data for all 50 states |
| `1_clean.py` | Join to CBSA crosswalk; compute block/county/CBSA percentages |
| `2_calculate_dkl.py` | Compute one-way KL divergence at block group level |
| `4_mutual_info.py` | Aggregate to MSA-level mutual information |
| `5_shapefiles.py` | Download Census TIGER block group boundaries |

Run the full pipeline for 2015 and 2020:

```bash
cd pipeline
python 0_download.py --years 2015 2020
python 1_clean.py --years 2015 2020
python 2_calculate_dkl.py --years 2015 2020
python 4_mutual_info.py
python 5_shapefiles.py --years 2020
```

### Notebooks

| Notebook | Description |
|----------|-------------|
| `notebooks/6_mutual_info_plots.ipynb` | Bar charts, violin plots, and lollipop chart of MI by CBSA |
| `notebooks/7_income_plots.ipynb` | DKL bin by income bracket for Atlanta, Chicago, Houston, New York |
| `notebooks/8_income_maps.ipynb` | Choropleth maps of block-level DKL income segregation |
| `notebooks/9_two_way_dkl.ipynb` | Two-way DKL (joint race × income) at tract level; heatmaps, dot plots, and choropleth maps |

### Supported Years & Datasets

| Year(s) | API dataset | Race | Income | Educ | Empl |
|---------|-------------|:----:|:------:|:----:|:----:|
| 2009–2023 | ACS 5-year | ✓ | ✓ | ✓ | ✓ |
| 2010 Decennial | SF1 | ✓ | | | |
| 2000 Decennial | SF1 + SF3 | ✓ | ✓ | ✓ | ✓ |
| 1990 | — | | | | |

> **Note:** 1990 block group data is not available via the Census API. Use [NHGIS](https://nhgis.org) for 1990 data.

### DKL Formula

For each block group *i* and demographic bin *j* within an MSA:

```
p_ni    = block_total / cbsa_total          # P(block i in MSA)
p_yj_ni = block_estimate / block_total      # P(bin j | block i)
p_yj    = cbsa_estimate / cbsa_total        # P(bin j in MSA)

dkl_block(i) = Σ_j  p_yj_ni * log2(p_yj_ni / p_yj)   # block-level DKL
MI(cbsa)     = Σ_i  p_ni * dkl_block(i)               # population-weighted MI
```

### Two-Way DKL Formula

`notebooks/9_two_way_dkl.ipynb` extends the one-way metric to the *joint* distribution of two variables (race and income) using ACS tables B19001A–I at the **census tract** level:

```
p_yjzk_ni = (tract households in race j, income k) / tract total
p_yjzk    = (MSA households in race j, income k)   / MSA total

dkl_2way(i) = Σ_{j,k}  p_yjzk_ni * log2(p_yjzk_ni / p_yjzk)

Residual(i) = dkl_2way(i) − dkl_race(i) − dkl_income(i)
```

The residual captures sorting specific to particular race × income combinations beyond what either dimension alone predicts.

> **Note:** B19001A–I cross-tabulations are published at tract level only, not block group level.

---

## R Scripts (`one-way-dkl/`)

The original R implementation. The `all_states_block/` subfolder contains scripts to reproduce DKL calculations and figures at the block group level for all US states for 2010, 2015, and 2020.

- `one-way-dkl/all_states_block/` — Main scripts for all-states block group analysis
- `one-way-dkl/chicago_block/` — Block group analysis for the Chicago MSA
- `one-way-dkl/chicago_tracts/` — Census tract analysis for the Chicago MSA

---

## Repository Structure

```
pipeline/               # Python pipeline (primary)
├── 0_download.py
├── 1_clean.py
├── 2_calculate_dkl.py
├── 3_income_2010.py
├── 4_mutual_info.py
├── 5_shapefiles.py
├── config.py
├── requirements.txt
├── utils/
│   ├── census_api.py
│   ├── cbsa_xwalk.py
│   ├── dkl.py
│   └── variable_maps.py
└── notebooks/
    ├── 6_mutual_info_plots.ipynb
    ├── 7_income_plots.ipynb
    ├── 8_income_maps.ipynb
    └── 9_two_way_dkl.ipynb
one-way-dkl/            # Original R scripts
archive/                # Legacy code
nicos_code/             # Original scripts (Nico Marchio)
```

---

For questions contact ivannar@uchicago.edu or bettencourt@uchicago.edu.
