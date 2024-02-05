# Purpose: Download block-level acs-5 census data for all metro areas in the US
#          data will be saved on an external hard drive
# Date: 2/2/2024
# Author: Ivanna


# ---- setup --------------------------------------------------------------------

pacman::p_load(tidyverse, tidycensus, magrittr, here, zeallot, arrow)
options(scipen=9999) # prevents numbers from switching to scientific notation
source(here("one-way-dkl/3_all_block/helper_functions.R"))


# focus on getting one metro area correctly, but make code into functio to be able to call for many simultaneously
# also, hard drive folder structure could look like:
# something like:
#   acs5_block_2015_data/
#     shapefiles/
#       chicago_community_areas.geojson which would just be neighborhood data for each city
#       all_us_block_groups.geojson (this could b an issue (?) is there a better format bc parquet is not geospatial)
#     IL/
#       race_blkgrp_15.parquet
#       education_blkgrp_15.parquet
#       income_blkgrp_15.parquet
#       employment_blkgrp_15.parquet
#     NY/
#     CA/
#     TX/
#     TN/
# OR:
#   acs5_block_2015_data/
#     shapefiles/
#       chicago_community_areas.geojson which would just be neighborhood data for each city
#       all_us_block_groups.geojson (this could b an issue (?) is there a better format bc parquet is not geospatial)
#       IL/
#        NY/
#        .
#        .
#        .
#     race_blkgrp_15.parquet (for all metro areas)
#     education_blkgrp_15.parquet
#     income_blkgrp_15.parquet
#     employment_blkgrp_15.parquet


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

# this is the part that will take forever to run here !! wait to run overnight or w external hard drive in JCL machines
state_codes <- c('RI', 'DE')

get_state_variable_data <- function(acs_year, state, acs_variables) {
  get_acs(year = acs_year,
          geography = "block group",
          survey = 'acs5',
          variables = acs_variables,
          state = state)
}

variables_list <- list(race = race, income = income)

for (vector_name in names(variables_list)) {
  var_df <- data.frame()
  for (state in state_codes) {
    variables_vector <- variables_list[[vector_name]]
    var_states_df <- get_state_variable_data(2015, state, variables_vector)
    var_df <- bind_rows(state_df, var_states_df)
  }
  filename <- paste0(vector_name, "_blkgrp_all_states_", "2015", ".parquet")
  write_parquet(var_df, here(paste0("one-way-dkl/3_all_block/", filename)))
}



# ------------------------------------

# save this massive ones into parquet files...or should we have individual ones so like race and state...?



















