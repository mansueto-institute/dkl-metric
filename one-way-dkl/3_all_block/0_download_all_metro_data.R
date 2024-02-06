# Purpose: Download block-level acs-5 census data for all metro areas in the US
#          data will be saved on an external hard drive
# Date: 2/2/2024
# Author: Ivanna


# ---- setup --------------------------------------------------------------------

pacman::p_load(tidyverse, tidycensus, magrittr, here, zeallot, arrow)

options(scipen=9999) # prevents numbers from switching to scientific notation

source(here("one-way-dkl/3_all_block/helper_functions.R"))

# 1. Obtain Census API Key here: https://api.census.gov/data/key_signup.html
# 2. Run census_api_key function to add API_KEY to .Renviron
# census_api_key('API_KEY', install = TRUE) 
# 3. Restart RStudio

# Another option is to simply run:
# Sys.getenv("API_KEY") 

# Read the .Renviron file (only necessary if you ran census_api_key()
readRenviron("~/.Renviron")


# ---- get all variable labels --------------------------------------------------------------------

c(labels, race, income, educ, empl) %<-%  get_var_labels(acs_year = 2020, # using only 2020 bc labels for 2015 == 2020
                                                         acs_dataset = 'acs5')

state_codes <- c(
  'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
  'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
  'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
  'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
  'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
)

get_state_variable_data <- function(acs_year, state, acs_variables) {
  get_acs(year = acs_year,
          geography = "block group",
          survey = 'acs5',
          variables = acs_variables,
          state = state) %>%
    mutate(state = state)
}

acs_vars_vector_list <- list(race = race, income = income, educ = educ, empl = empl)

process_data <- function(year) {
  map(names(acs_vars_vector_list), ~ {
    vector_name <- .x
    vector <- acs_vars_vector_list[[vector_name]]
    
    var_df <- map_dfr(state_codes, ~ get_state_variable_data(year, .x, vector))
    
    # save to external drive
    filename <- paste0(vector_name, "_blkgrp_all_states_", year, ".parquet")
    write_parquet(var_df, paste0("E:/acs5_block_", year, "_data/raw/", filename))
  })
}

process_data(2015)
process_data(2020)

 

















