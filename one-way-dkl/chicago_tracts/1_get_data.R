##################################################
## Gets ACS 5 data to create a dataset for DKL Calculations
##
## Nov 17 2023
##################################################

# install.packages("pacman")
pacman::p_load(tidyverse, sf, lwgeom, tidycensus, scales, viridis, DT, shiny, 
               readxl, patchwork, arrow)

# get helper functions to clean data
source("one-way-dkl/chicago_block/clean_one_way_acs.R")

options(scipen=9999)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
wd_dev <- getwd()

# Setup -------------------------------------------------------------------

# 1. Obtain Census API Key here: https://api.census.gov/data/key_signup.html
# 2. Run census_api_key function to add API_KEY to .Renviron
# census_api_key('API_KEY', install = TRUE) 
# 3. Restart RStudio

# Another option is to simply run:
# Sys.getenv("API_KEY") 

# Read the .Renviron file (only necessary if you ran census_api_key()
readRenviron("~/.Renviron")

# read in ACS5 data ------------------------------------------------------

acs5_vars_2015 <- describe_acs_vars_yr(year = 2015, dataset = 'acs5')
acs5_vars_2020 <- describe_acs_vars_yr(year = 2020, dataset = 'acs5')

acs5_vars_selected <- c('B23025_004','B23025_005','B23025_006','B23025_007',
                        'B06001_002','B06001_003','B06001_004','B06001_005','B06001_006','B06001_007','B06001_008','B06001_009','B06001_010','B06001_011','B06001_012',
                        'B19001_002','B19001_003','B19001_004','B19001_005','B19001_006','B19001_007','B19001_008','B19001_009','B19001_010','B19001_011','B19001_012','B19001_013','B19001_014','B19001_015','B19001_016','B19001_017',
                        'B19001A_002','B19001A_003','B19001A_004','B19001A_005','B19001A_006','B19001A_007','B19001A_008','B19001A_009','B19001A_010','B19001A_011','B19001A_012','B19001A_013','B19001A_014','B19001A_015','B19001A_016','B19001A_017',
                        'B19001B_002','B19001B_003','B19001B_004','B19001B_005','B19001B_006','B19001B_007','B19001B_008','B19001B_009','B19001B_010','B19001B_011','B19001B_012','B19001B_013','B19001B_014','B19001B_015','B19001B_016','B19001B_017',
                        'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
                        'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
                        'B19001D_002','B19001D_003','B19001D_004','B19001D_005','B19001D_006','B19001D_007','B19001D_008','B19001D_009','B19001D_010','B19001D_011','B19001D_012','B19001D_013','B19001D_014','B19001D_015','B19001D_016','B19001D_017',
                        'B19001E_002','B19001E_003','B19001E_004','B19001E_005','B19001E_006','B19001E_007','B19001E_008','B19001E_009','B19001E_010','B19001E_011','B19001E_012','B19001E_013','B19001E_014','B19001E_015','B19001E_016','B19001E_017',
                        'B19001F_002','B19001F_003','B19001F_004','B19001F_005','B19001F_006','B19001F_007','B19001F_008','B19001F_009','B19001F_010','B19001F_011','B19001F_012','B19001F_013','B19001F_014','B19001F_015','B19001F_016','B19001F_017',
                        'B19001G_002','B19001G_003','B19001G_004','B19001G_005','B19001G_006','B19001G_007','B19001G_008','B19001G_009','B19001G_010','B19001G_011','B19001G_012','B19001G_013','B19001G_014','B19001G_015','B19001G_016','B19001G_017',
                        'B19001H_002','B19001H_003','B19001H_004','B19001H_005','B19001H_006','B19001H_007','B19001H_008','B19001H_009','B19001H_010','B19001H_011','B19001H_012','B19001H_013','B19001H_014','B19001H_015','B19001H_016','B19001H_017',
                        'B19001I_002','B19001I_003','B19001I_004','B19001I_005','B19001I_006','B19001I_007','B19001I_008','B19001I_009','B19001I_010','B19001I_011','B19001I_012','B19001I_013','B19001I_014','B19001I_015','B19001I_016','B19001I_017',
                        'B08126_002','B08126_003','B08126_004','B08126_005','B08126_006','B08126_007','B08126_008','B08126_009','B08126_010','B08126_011','B08126_012','B08126_013','B08126_014','B08126_015',        
                        'B08124_002','B08124_003','B08124_004','B08124_005','B08124_006','B08124_007',
                        'B15003_002','B15003_003','B15003_004','B15003_005','B15003_006','B15003_007','B15003_008','B15003_009','B15003_010','B15003_011','B15003_012','B15003_013','B15003_014','B15003_015','B15003_016',
                        'B15003_017','B15003_018','B15003_019','B15003_020','B15003_021','B15003_022','B15003_023','B15003_024','B15003_025',
                        'B02001_002','B02001_003','B02001_004','B02001_005','B02001_006','B02001_007','B02001_008',
                        'B03001_002','B03001_003')

# Subset to states of interest (use state_codes list to get all states)
state_list <- c('IL','WI','IN')

# Use purrr function map_df to run a get_acs call that loops over all states
acs_tract_all_us_data_2020 <- map_df(state_list, function(x) {
  get_acs(year = 2020, geography = "tract", survey = 'acs5', 
          variables = acs5_vars_selected, 
          state = x)
})

acs_tract_all_us_data_2015 <- map_df(state_list, function(x) {
  get_acs(year = 2015, geography = "tract", survey = 'acs5', 
          variables = acs5_vars_selected, 
          state = x)
})

# save raw files as parquet to data/ folder
write_parquet(acs_tract_all_us_data_2015, "data/raw_acs_tract_all_us_data_2015.parquet")
write_parquet(acs_tract_all_us_data_2020, "data/raw_acs_tract_all_us_data_2020.parquet")

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

df_2015 <- clean_acs(acs = acs_tract_all_us_data_2015, 
                     acs_vars = acs5_vars_2015, 
                     cbsa_xwalk = cbsa_xwalk_2015, 
                     state_xwalk = state_xwalk) # takes a while to run

df_2020 <- clean_acs(acs = acs_tract_all_us_data_2020, 
                     acs_vars = acs5_vars_2020, 
                     cbsa_xwalk = cbsa_xwalk_2020, 
                     state_xwalk = state_xwalk) # takes a while to run


# save clean data
write_parquet(df_2020, "data/clean_acs_tract_all_us_data_2020.parquet")
write_parquet(df_2015, "data/clean_acs_tract_all_us_data_2015.parquet")





