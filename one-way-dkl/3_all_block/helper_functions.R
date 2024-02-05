# Purpose: write a set of functions to call to be able to download block-group
#          level data for all metro areas in the USA
# Date: 2/2/2024

# install.packages("pacman")
pacman::p_load(tidyverse, tidycensus, magrittr)

# ------------- functions to get variable labels -------------------

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


get_var_labels <- function(acs_year, acs_dataset) {
  # returns a clean data frame of the ace variable labels for race,
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
  
  return(list(acs5_vars, race, income, educ, empl_status))
}


# ------------- functions to get variable labels -------------------



