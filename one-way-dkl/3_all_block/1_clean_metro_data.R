# Purpose: Join block-level acs-5 census data to all metro areas in the US
#          along w metro-area level summaries of estimates for dkl calculation
# Date: 2/13/2024
# Author: Ivanna


# ----- setup -----------------------------------------------------

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


# ---- add CBSA-level measurements for DKL calculation --------------

# Download state codes via tidycensus' "fips_codes" data set
state_xwalk <- as.data.frame(fips_codes) %>%
  rename(state_fips = state_code,
         state_codes = state,
         county_name = county) %>%
  mutate(county_fips = paste0(state_fips, county_code)) %>%
  select(-state_codes)

write_csv(state_xwalk, paste0(data_path, "state_crosswalk.csv"))

# Make lists for FIPS and codes
state_fips <- unique(state_xwalk$state_fips)[1:51]
state_codes <- unique(state_xwalk$state_codes)[1:51]

## get and save 2020 metro crosswalk
xwalk_url <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls'

tmp_filepath <- paste0(tempdir(), '\\', basename(xwalk_url))
download.file(url = xwalk_url, destfile = tmp_filepath, mode = 'wb')
cbsa_xwalk <- read_excel(tmp_filepath, sheet = 1, range = cell_rows(3:1919))
cbsa_xwalk <- cbsa_xwalk %>% 
  select_all(~gsub("\\s+|\\.|\\/", "_", .)) %>%
  rename_all(list(tolower)) %>%
  mutate(fips_state_code = str_pad(fips_state_code, width=2, side="left", pad="0"),
         fips_county_code = str_pad(fips_county_code, width=3, side="left", pad="0"),
         county_fips = paste0(fips_state_code,fips_county_code)) %>%
  rename(cbsa_fips = cbsa_code,
         area_type = metropolitan_micropolitan_statistical_area) %>%
  select(county_fips,cbsa_fips,cbsa_title,area_type,central_outlying_county)

write_csv(cbsa_xwalk, paste0(data_path, "cbsa_crosswalk_2020.csv"))


# ---- join crosswalks to ACS data to get metro area information -----------

# race
clean_race_15 <- join_metro_data(race_15, labels, cbsa_xwalk, state_xwalk)
clean_race_20 <- join_metro_data(race_20, labels, cbsa_xwalk, state_xwalk)

# income
clean_income_15 <- join_metro_data(income_15, labels, cbsa_xwalk, state_xwalk)
clean_income_20 <- join_metro_data(income_20, labels, cbsa_xwalk, state_xwalk)

# empl
clean_empl_15 <- join_metro_data(empl_15, labels, cbsa_xwalk, state_xwalk)
clean_empl_20 <- join_metro_data(empl_20, labels, cbsa_xwalk, state_xwalk)

# educ
clean_educ_15 <- join_metro_data(educ_15, labels, cbsa_xwalk, state_xwalk)
clean_educ_20 <- join_metro_data(educ_20, labels, cbsa_xwalk, state_xwalk)

# ---- save ----------

folder_15 <- paste0(data_path, "acs5_block_2015_data/")
folder_20 <- paste0(data_path, "acs5_block_2020_data/")

write_parquet(clean_race_15, paste0(folder_15, "race_15_blkgrp_all_states.parquet"))
write_parquet(clean_race_20, paste0(folder_20, "race_20_blkgrp_all_states.parquet"))
write_parquet(clean_educ_15, paste0(folder_15, "educ_15_blkgrp_all_states.parquet"))
write_parquet(clean_educ_20, paste0(folder_20, "educ_20_blkgrp_all_states.parquet"))
write_parquet(clean_income_15, paste0(folder_15, "income_15_blkgrp_all_states.parquet"))
write_parquet(clean_income_20, paste0(folder_20, "income_20_blkgrp_all_states.parquet"))
write_parquet(clean_empl_15, paste0(folder_15, "empl_15_blkgrp_all_states.parquet"))
write_parquet(clean_empl_20, paste0(folder_20, "empl_20_blkgrp_all_states.parquet"))






