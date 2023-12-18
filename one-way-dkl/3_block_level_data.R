####################
# explore differences between get_decennial and get_acs in terms of variables
# since block is only available at get_decennial
####################


pacman::p_load(tidyverse, arrow, stringr, tidycensus, readxl)

options(scipen=9999)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
wd_dev <- getwd()

# get helper functions to clean data
source("clean_one_way_acs.R")


# ---------- get block-level demographic vars ----------------

block_vars_20 <- describe_acs_vars_yr(year = 2020, dataset = 'acs5') %>%
  filter(geography == "block group")

block_vars_15 <- describe_acs_vars_yr(year = 2015, dataset = 'acs5') %>%
  filter(geography == "block group")

race <- block_vars_20 %>% filter(str_detect(name, '^B03002_')) %>% pull(name)
income <- block_vars_20 %>% filter(str_detect(name, '^B19001_')) %>% pull(name)
educ <- block_vars_20 %>% filter(str_detect(name, '^B15003_')) %>% pull(name)
empl_status <- block_vars_20 %>% filter(str_detect(name, '^B23025_')) %>% pull(name)

# the rest are unfortunately only available broken down sex or another variable
# leaving these out for now
# age <- block_vars %>% filter(str_detect(name, '^B16004_')) %>% pull(name) # over 5 years
# occupation <- block_vars %>% filter(name, '^') %>% pull(name)
# industry <- block_vars %>% filter(name, '^') %>% pull(name)

acs_vars_selected <- c(race, income, educ, empl_status)
rm(race, income, educ, empl_status)

# Subset to states of interest (use state_codes list to get all states)
state_list <- c('IL','WI','IN')

# Use purrr function map_df to run a get_acs call that loops over all states
acs_block_all_us_data_2020 <- map_df(state_list, function(x) {
  get_acs(year = 2020, geography = "block group", survey = 'acs5', 
          variables = acs_vars_selected, 
          state = x)
})

acs_block_all_us_data_2015 <- map_df(state_list, function(x) {
  get_acs(year = 2015, geography = "block group", survey = 'acs5', 
          variables = acs_vars_selected, 
          state = x)
})

# save raw files as parquet to data/ folder
write_parquet(acs_block_all_us_data_2015, "data/raw_acs_block_grp_all_us_data_2015.parquet")
write_parquet(acs_block_all_us_data_2020, "data/raw_acs_block_grp_all_us_data_2020.parquet")

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

df_2015 <- clean_acs(acs = acs_block_all_us_data_2015, 
                     acs_vars = block_vars_15, 
                     cbsa_xwalk = cbsa_xwalk_2015, 
                     state_xwalk = state_xwalk) # takes a while to run

df_2020 <- clean_acs(acs = acs_block_all_us_data_2020, 
                     acs_vars = block_vars_20, 
                     cbsa_xwalk = cbsa_xwalk_2020, 
                     state_xwalk = state_xwalk) # takes a while to run


# save clean data
write_parquet(df_2020, "data/clean_acs_block_grp_all_us_data_2020.parquet")
write_parquet(df_2015, "data/clean_acs_block_grp_all_us_data_2015.parquet")



  
  
  

