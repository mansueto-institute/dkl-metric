####################
## Gets ACS 5 data at the block level to create a dataset for DKL Calculations
##
## Dec 20 2023
####################

# install.packages("pacman") # install if not already installed
pacman::p_load(here, tidyverse, arrow, stringr, tidycensus, readxl, magrittr)

options(scipen=9999)

# get helper functions to clean data
source(here("one-way-dkl/clean_one_way_acs.R"))

# Setup --------------------------------------------------------------------

# 1. Obtain Census API Key here: https://api.census.gov/data/key_signup.html
# 2. Run census_api_key function to add API_KEY to .Renviron
# census_api_key('API_KEY', install = TRUE) 
# 3. Restart RStudio

# Another option is to simply run:
# Sys.getenv("API_KEY") 

# Read the .Renviron file (only necessary if you ran census_api_key()
readRenviron("~/.Renviron")

# ------------- get acs5 data from census api ------------------------------

block_vars_20 <- describe_acs_vars_yr(year = 2020, dataset = 'acs5') %>%
  filter(geography == "block group")

block_vars_15 <- describe_acs_vars_yr(year = 2015, dataset = 'acs5') %>%
  filter(geography == "block group")

race <- block_vars_20 %>% filter(str_detect(name, '^B03002_')) %>% pull(name)
income <- block_vars_20 %>% filter(str_detect(name, '^B19001_')) %>% pull(name)
educ <- block_vars_20 %>% filter(str_detect(name, '^B15003_')) %>% pull(name)
empl_status <- block_vars_20 %>% filter(str_detect(name, '^B23025_')) %>% pull(name)

acs_vars_selected <- c(race, income, educ, empl_status)
rm(race, income, educ, empl_status)

block_vars_15 %<>%
  filter(name %in% acs_vars_selected)

block_vars_20 %<>%
  filter(name %in% acs_vars_selected)

# Subset to states of interest (use state_codes list to get all states)
state_list <- c('IL','WI','IN')

# Use purrr function map_df to run a get_acs call that loops over all states
acs_block_all_us_data_2020 <- map_df(state_list, function(x) {
  get_acs(year = 2020, geography = "block group", survey = 'acs5', 
          variables = acs_vars_selected, 
          state = x)
  }) %>% 
  separate(col = 'variable',  
           into = c('variable_group','variable_item'),
           sep = c('_'),
           remove = FALSE,
           extra = "merge")

acs_block_all_us_data_2015 <- map_df(state_list, function(x) {
  get_acs(year = 2015, geography = "block group", survey = 'acs5', 
          variables = acs_vars_selected, 
          state = x)
  }) %>% 
  separate(col = 'variable',  
           into = c('variable_group','variable_item'),
           sep = c('_'),
           remove = FALSE,
           extra = "merge")

# save raw files as parquet to data/ folder
write_parquet(acs_block_all_us_data_2015, here("one-way-dkl/data/raw_acs_block_grp_all_us_data_2015.parquet"))
write_parquet(acs_block_all_us_data_2020, here("one-way-dkl/data/raw_acs_block_grp_all_us_data_2020.parquet"))

# ------------- get relevant acs5 variable labels ------------------------------

df <- block_vars_20 %>%
  select(name, label) %>%
  distinct() %>%
  mutate(label = gsub("^Estimate!!Total[:]*", "", label),
         label = ifelse(label == "", "Total", label),
         label = gsub("In labor force", "", label),
         label = gsub("Civilian labor force", "", label),
         label = gsub("!!|:", "", label)) %>%
  separate(col = 'name',  
           into = c('variable_group','variable_item'),
           sep = c('_'),
           remove = FALSE,
           extra = "merge") %>%
  mutate(group_label = case_when(variable_group == "B03002" ~ "Race/Ethnicity",
                                 variable_group == "B15003" ~ "Education attainment",
                                 variable_group == "B19001" ~ "Household Income",
                                 variable_group == "B23025" ~ "Employment")) %>%
  mutate(label = case_when(name == "B03002_012" ~ "Hispanic or Latino (any race)",
                           name %in% c("B03002_010", "B03002_011") ~ "Two or more races",
                           name %in% c("B03002_003", "B03002_004", "B03002_005", "B03002_006", "B03002_007",
                                       "B03002_008", "B03002_009", "B03002_010", "B03002_011") ~ str_replace(label, "Not Hispanic or Latino", ""),
                           TRUE ~ label)) %>%
  filter( ! label %in% c("Total", "", "Not Hispanic or Latino"),
          ! name %in% c("B03002_013", "B03002_014", "B03002_015", "B03002_016", 
                        "B03002_017", "B03002_018", "B03002_019", "B03002_020", 
                        "B03002_021"))

write_rds(df, here("one-way-dkl/data/block_grp_labels.rds"))
