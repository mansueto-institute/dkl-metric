# Purpose: write a set of functions to call to be able to download block-group
#          level data for all metro areas in the USA
# Date: 2/2/2024

# install.packages("pacman")
pacman::p_load(tidyverse, tidycensus, magrittr, readxl)

# ------------- functions to get variable labels -------------------

get_var_labels <- function(acs_year, acs_dataset) {
  # returns a clean data frame of the acs variable labels for race,
  # household income, education attainment, and employment status
  # along with their descriptions for the specified year and acs dataset
  
  acs5_vars <- describe_all_variables(acs_year, acs_dataset)
  
  race <- acs5_vars %>% filter(str_detect(name, '^B03002_')) %>% pull(name)
  income <- acs5_vars %>% filter(str_detect(name, '^B19001_')) %>% pull(name)
  educ <- acs5_vars %>% filter(str_detect(name, '^B15003_')) %>% pull(name)
  empl_status <- acs5_vars %>% filter(str_detect(name, '^B23025_')) %>% pull(name)
  
  acs_vars_selected <- c(race, income, educ, empl_status)
  
  acs5_vars %<>%
    filter(name %in% acs_vars_selected) %>%
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
                             name %in% c("B03002_003", "B03002_004", "B03002_005", "B03002_006", "B03002_007",
                                         "B03002_008", "B03002_009", "B03002_010", "B03002_011") ~ str_replace(label, "Not Hispanic or Latino", ""),
                             TRUE ~ label)) %>%
    filter( ! label %in% c("Total", "", "Not Hispanic or Latino"),
            ! name %in% c("B03002_010", "B03002_011", "B03002_013", "B03002_014", "B03002_015", 
                          "B03002_016", "B03002_017", "B03002_018", "B03002_019", "B03002_020", 
                          "B03002_021"))
  
  return(list(acs5_vars, race, income, educ, empl_status)) # need zeallot package to unpack like python tuples when calling the function
}


describe_all_variables <- function(acs_year, acs_dataset){
  # returns a dataframe with clean variable names and census codes to make it easier
  # to look for he variables we want to include in the analysis
  
  # get all acs variable labels and descriptions for the specified year
  acs5_vars <- load_variables(year = acs_year, 
                              dataset = acs_dataset, 
                              cache = FALSE)
  
  # separate concept column so its easier to sort through different categories
  # and see the right variable names for our variables of interest
  acs5_vars <- acs5_vars %>% separate(col = 'concept',
                                      into = c('concept_main','concept_part'),
                                      sep = c(' BY '),
                                      remove = FALSE,
                                      extra = "merge") %>%
    mutate(concept_part = case_when(is.na(concept_part) ~ 'TOTAL',
                                    TRUE ~ as.character(concept_part)))
  
  return(acs5_vars)
}


# ------------- functions to clean data and prepare for dkl -------------------

get_cbsa_xwalk <- function(xwalk_url) {
  # downloads a cbsa cross walk file from the census reference files based on the file's URL
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
}

join_metro_data <- function(acs5_dataset, acs5_var_labels, cbsa_xwalk, state_xwalk) {
  df <- acs5_dataset %>%
    rename(state_codes = state) %>%
    left_join(acs5_var_labels, by = c("variable" = "name")) %>%
    # filter all empty labels (don't need hispanic racial breakdown, etc)
    filter(!is.na(label)) %>%
    rename_all(list(tolower)) %>%
    mutate(county_fips = str_sub(geoid,1,5),
           tract = str_sub(geoid,6,9),
           block_group = str_sub(geoid,10,12)) %>%
    left_join(state_xwalk, by = c('county_fips'='county_fips')) %>%
    left_join(cbsa_xwalk, by = c('county_fips'='county_fips')) %>%
    group_by(geoid, variable_group) %>% mutate(block_total = sum(estimate)) %>% ungroup() %>%
    group_by(county_fips, variable) %>% mutate(county_estimate = sum(estimate)) %>% ungroup() %>%
    group_by(county_fips, variable_group) %>% mutate(county_total = sum(estimate)) %>% ungroup() %>%
    group_by(cbsa_fips, variable) %>% mutate(cbsa_estimate = sum(estimate)) %>% ungroup() %>%
    group_by(cbsa_fips, variable_group) %>% mutate(cbsa_total = sum(estimate)) %>% ungroup() %>%
    mutate(block_pct = estimate / block_total,
           county_pct = county_estimate / county_total,
           cbsa_pct = cbsa_estimate / cbsa_total) %>%
    rename(block_estimate = estimate,
           block_fips = geoid) %>%
    select(block_fips,county_fips,county_name,cbsa_fips,cbsa_title,area_type,central_outlying_county,state_codes,
           state_fips,state_name,variable,variable_group,variable_item,group_label,label,block_pct,block_estimate,
           moe,block_total,county_pct,county_estimate,county_total,cbsa_pct,cbsa_estimate,cbsa_total) %>%
    arrange(county_fips, block_fips, variable) %>%
    mutate_at(vars(block_pct,county_pct,cbsa_pct), ~replace(., is.nan(.), 0))
  
  return(df)
}


# -------------------- function to calculate dkl ----------------------------

calculate_dkl <- function(acs5_dataset) {
  
  dkl_df  <- acs5_dataset %>% 
    mutate(p_ni = block_total / cbsa_total, # Prob of being in block in MSA 
           p_ni_yj = block_estimate / cbsa_estimate, # Prob of being in block among people in bin 
           p_yj = cbsa_estimate / cbsa_total, # Prob of being in bin for everyone in MSA 
           p_yj_ni = block_estimate / block_total) %>%
    # replace all NaN porduced from 0/0 to 0
    mutate_at(vars(p_ni,p_ni_yj,p_yj,p_yj_ni), ~replace(., is.nan(.), 0)) %>%
    mutate(dkl_log_i = log2(p_yj_ni / p_yj), # share of income in tract relative to share of income in metro
           djl_log_j = log2(p_ni_yj / p_ni) # tract share of metro bin relative to share of tract in metro
    ) %>%
    # replace all NaN and -Inf produced from taking log(0) and v small numbers
    mutate_at(vars(dkl_log_i, djl_log_j), ~replace(., is.infinite(.), 0)) %>%
    mutate_at(vars(dkl_log_i, djl_log_j), ~replace(., is.nan(.), 0)) %>%
    mutate(dkl_block_j = p_yj_ni * dkl_log_i, # DKL block component
           dkl_bin_i = p_ni_yj * djl_log_j) %>% # DKL bin component
    # Sum DKL block components
    group_by(variable_group, block_fips) %>% 
    mutate(dkl_block = sum(dkl_block_j)) %>% 
    ungroup() %>% 
    # Sum DKL bin components
    group_by(variable_group, cbsa_fips, variable) %>% 
    mutate(dkl_bin = sum(dkl_bin_i )) %>% 
    ungroup() # Sum DKL bin components
  
  return(dkl_df)
}



