# Purpose: get summaries for each state
# Date: 2/13/2024
# Author: Ivanna

pacman::p_load(tidyverse, tidycensus, readxl, magrittr, here, arrow)
source(here("one-way-dkl/3_all_block/helper_functions.R"))

# ---- read data ---------------------------------------

folder_15 <- 'E:/acs5_block_2015_data/'
folder_20 <- 'E:/acs5_block_2020_data/'

race_15 <- read_parquet(paste0(folder_15, "dkl_race_15_blkgrp_all_states.parquet"))
income_15 <- read_parquet(paste0(folder_15, "dkl_income_15_blkgrp_all_states.parquet"))
educ_15 <- read_parquet(paste0(folder_15, "dkl_educ_15_blkgrp_all_states.parquet"))
empl_15 <- read_parquet(paste0(folder_15, "dkl_empl_15_blkgrp_all_states.parquet"))
race_20 <- read_parquet(paste0(folder_20, "dkl_race_20_blkgrp_all_states.parquet"))
income_20 <- read_parquet(paste0(folder_20, "dkl_income_20_blkgrp_all_states.parquet"))
educ_20 <- read_parquet(paste0(folder_20, "dkl_educ_20_blkgrp_all_states.parquet"))
empl_20 <- read_parquet(paste0(folder_20, "dkl_empl_20_blkgrp_all_states.parquet"))

# ---- race ----

# do one at a time then remove from environment bc datasets too heavy?



