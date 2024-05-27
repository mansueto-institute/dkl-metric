# Purpose: calculate DKL
# Date: 2/13/2024
# Author: Ivanna

pacman::p_load(tidyverse, tidycensus, readxl, magrittr, here, arrow)
source(here("one-way-dkl/3_all_block/helper_functions.R"))

# ---- read data ---------------------------------------

folder_15 <- 'E:/acs5_block_2015_data/'
folder_20 <- 'E:/acs5_block_2020_data/'

race_15 <- read_parquet(paste0(folder_15, "race_15_blkgrp_all_states.parquet"))
income_15 <- read_parquet(paste0(folder_15, "income_15_blkgrp_all_states.parquet"))
educ_15 <- read_parquet(paste0(folder_15, "educ_15_blkgrp_all_states.parquet"))
empl_15 <- read_parquet(paste0(folder_15, "empl_15_blkgrp_all_states.parquet"))
race_20 <- read_parquet(paste0(folder_20, "race_20_blkgrp_all_states.parquet"))
income_20 <- read_parquet(paste0(folder_20, "income_20_blkgrp_all_states.parquet"))
educ_20 <- read_parquet(paste0(folder_20, "educ_20_blkgrp_all_states.parquet"))
empl_20 <- read_parquet(paste0(folder_20, "empl_20_blkgrp_all_states.parquet"))

# ---- calculate DKL -----------------------------------

dkl_race_15 <- calculate_dkl(race_15)
dkl_income_15 <- calculate_dkl(income_15)
dkl_educ_15 <- calculate_dkl(educ_15)
dkl_empl_15 <- calculate_dkl(empl_15)

dkl_race_20 <- calculate_dkl(race_20)
dkl_income_20 <- calculate_dkl(income_20)
dkl_educ_20 <- calculate_dkl(educ_20)
dkl_empl_20 <- calculate_dkl(empl_20)

# ---- save --------------------------------------------

write_parquet(dkl_race_15, paste0(folder_15, "dkl_race_15_blkgrp_all_states.parquet"))
write_parquet(dkl_race_20, paste0(folder_20, "dkl_race_20_blkgrp_all_states.parquet"))
write_parquet(dkl_educ_15, paste0(folder_15, "dkl_educ_15_blkgrp_all_states.parquet"))
write_parquet(dkl_educ_20, paste0(folder_20, "dkl_educ_20_blkgrp_all_states.parquet"))
write_parquet(dkl_income_15, paste0(folder_15, "dkl_income_15_blkgrp_all_states.parquet"))
write_parquet(dkl_income_20, paste0(folder_20, "dkl_income_20_blkgrp_all_states.parquet"))
write_parquet(dkl_empl_15, paste0(folder_15, "dkl_empl_15_blkgrp_all_states.parquet"))
write_parquet(dkl_empl_20, paste0(folder_20, "dkl_empl_20_blkgrp_all_states.parquet"))








