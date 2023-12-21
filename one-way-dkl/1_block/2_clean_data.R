####################
## Gets ACS 5 data at the block level to create a dataset for DKL Calculations
##
## Dec 20 2023
####################


pacman::p_load(here, tidyverse, arrow, stringr, tidycensus, readxl, magrittr)

options(scipen=9999)

# get helper functions to clean data
source(here("one-way-dkl/clean_one_way_acs.R"))

# ----------- load intermediate acs5 data -------------------------------

acs_block_all_us_data_2015 <- read_parquet(here("one-way-dkl/data/raw_acs_block_grp_all_us_data_2015.parquet"))
acs_block_all_us_data_2020 <- read_parquet(here("one-way-dkl/data/raw_acs_block_grp_all_us_data_2020.parquet"))
labels <- read_rds(here("one-way-dkl/data/block_grp_labels.rds"))

# read in census crosswalks ---------------------------------------------

## State crosswalk

# Download state codes via tidycensus' "fips_codes" data set
state_xwalk <- as.data.frame(fips_codes) %>%
  rename(state_fips = state_code,
         state_codes = state,
         county_name = county) %>%
  mutate(county_fips = paste0(state_fips, county_code))

# Make lists for FIPS and codes
state_fips <- unique(state_xwalk$state_fips)[1:51]
state_codes <- unique(state_xwalk$state_codes)[1:51]

## Metro crosswalk
xwalk_url_2020 <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls'
xwalk_url_2015 <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2015/delineation-files/list1.xls'

cbsa_xwalk_2015 <- get_cbsa_xwalk(xwalk_url_2015)    
cbsa_xwalk_2020 <- get_cbsa_xwalk(xwalk_url_2020)


# join crosswalks to acs data -------------------------------------------

df_2015 <- clean_acs_block(acs5_data = acs_block_all_us_data_2015, 
                     acs5_var_labels = labels, 
                     cbsa_xwalk = cbsa_xwalk_2015, 
                     state_xwalk = state_xwalk) # takes a while to run

df_2020 <- clean_acs_block(acs5_data = acs_block_all_us_data_2020, 
                     acs5_var_labels = labels, 
                     cbsa_xwalk = cbsa_xwalk_2020, 
                     state_xwalk = state_xwalk) # takes a while to run

# save clean data
write_parquet(df_2020, here("one-way-dkl/data/clean_acs_block_grp_all_us_data_2020.parquet"))
write_parquet(df_2015, here("one-way-dkl/data/clean_acs_block_grp_all_us_data_2015.parquet"))

  
  
  

