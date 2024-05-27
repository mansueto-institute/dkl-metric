# Purpose: calculate DKL
# Date: 4/16/2024
# Author: Ivanna

pacman::p_load(tidyverse, tidycensus, readxl, magrittr, here, arrow)
source(here("one-way-dkl/3_all_block/helper_functions.R"))

# ---- read data ---------------------------------------

folder_15 <- 'E:/acs5_block_2015_data/'

race_15 <- read_parquet(paste0(folder_15, "cbsa_15_race_15_blkgrp_all_states.parquet"))
income_15 <- read_parquet(paste0(folder_15, "cbsa_15_income_15_blkgrp_all_states.parquet"))
educ_15 <- read_parquet(paste0(folder_15, "cbsa_15_educ_15_blkgrp_all_states.parquet"))
empl_15 <- read_parquet(paste0(folder_15, "cbsa_15_empl_15_blkgrp_all_states.parquet"))


# ---- calculate DKL -----------------------------------

dkl_race_15 <- calculate_dkl(race_15)
dkl_income_15 <- calculate_dkl(income_15)
dkl_educ_15 <- calculate_dkl(educ_15)
dkl_empl_15 <- calculate_dkl(empl_15)


# ---- save --------------------------------------------

write_parquet(dkl_race_15, paste0(folder_15, "cbsa_15_dkl_race_15_blkgrp_all_states.parquet"))
write_parquet(dkl_educ_15, paste0(folder_15, "cbsa_15_dkl_educ_15_blkgrp_all_states.parquet"))
write_parquet(dkl_income_15, paste0(folder_15, "cbsa_15_dkl_income_15_blkgrp_all_states.parquet"))
write_parquet(dkl_empl_15, paste0(folder_15, "cbsa_15_dkl_empl_15_blkgrp_all_states.parquet"))

