# Purpose: Join block-level acs-5 census data to all metro areas in the US
#          along w metro-area level summaries of estimates for dkl calculation
# Date: 4/1/2024
# Author: Ivanna


# ----- setup -----------------------------------------------------

# install.pacman("pacman")
pacman::p_load(tidyverse, tidycensus, readxl, magrittr, here, arrow)

options(scipen=9999)

source(here("one-way-dkl/3_all_block/helper_functions.R"))

# ----- read in saved raw data -----------------------------------------------

data_path <- 'E:/'
race_15 <- read_parquet(paste0(data_path, "acs5_block_2015_data/raw/race_blkgrp_all_states_2015.parquet"))
income_15 <- read_parquet(paste0(data_path, "acs5_block_2015_data/raw/income_blkgrp_all_states_2015.parquet"))
educ_15 <- read_parquet(paste0(data_path, "acs5_block_2015_data/raw/educ_blkgrp_all_states_2015.parquet"))
empl_15 <- read_parquet(paste0(data_path, "acs5_block_2015_data/raw/empl_blkgrp_all_states_2015.parquet"))
race_20 <- read_parquet(paste0(data_path, "acs5_block_2020_data/raw/race_blkgrp_all_states_2020.parquet"))
income_20 <- read_parquet(paste0(data_path, "acs5_block_2020_data/raw/income_blkgrp_all_states_2020.parquet"))
educ_20 <- read_parquet(paste0(data_path, "acs5_block_2020_data/raw/educ_blkgrp_all_states_2020.parquet"))
empl_20 <- read_parquet(paste0(data_path, "acs5_block_2020_data/raw/empl_blkgrp_all_states_2020.parquet"))

labels <- read_rds(here("one-way-dkl/data/block_grp_labels.rds"))

state_xwalk <- read_csv(paste0(data_path, "state_crosswalk.csv"))

# cbsa crosswalk urls
xwalk_url_09 <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2009/historical-delineation-files/list3.xls'
xwalk_url_15 <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2015/delineation-files/list1.xls'
xwalk_url_20 <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls'

# read in crosswalks for each year
cbsa_xwalk_09 <- get_cbsa_xwalk(xwalk_url_09, 2009)
cbsa_xwalk_15 <- get_cbsa_xwalk(xwalk_url_15, 2015)
cbsa_xwalk_20 <- get_cbsa_xwalk(xwalk_url_20, 2020)

# ---- join crosswalks to ACS data to get metro area information -----------

# race
clean_race_15 <- join_metro_data(race_15, labels, cbsa_xwalk_15, state_xwalk)

# income
clean_income_15 <- join_metro_data(income_15, labels, cbsa_xwalk_15, state_xwalk)

# empl
clean_empl_15 <- join_metro_data(empl_15, labels, cbsa_xwalk_15, state_xwalk)

# educ
clean_educ_15 <- join_metro_data(educ_15, labels, cbsa_xwalk_15, state_xwalk)

# ---- save 2015 files ----------

# still don't have 2010, and 2020 already saved so unnecessary here

folder_15 <- paste0(data_path, "acs5_block_2015_data/")

write_parquet(clean_race_15, paste0(folder_15, "cbsa_15_race_15_blkgrp_all_states.parquet"))
write_parquet(clean_educ_15, paste0(folder_15, "cbsa_15_educ_15_blkgrp_all_states.parquet"))
write_parquet(clean_income_15, paste0(folder_15, "cbsa_15_income_15_blkgrp_all_states.parquet"))
write_parquet(clean_empl_15, paste0(folder_15, "cbsa_15_empl_15_blkgrp_all_states.parquet"))

