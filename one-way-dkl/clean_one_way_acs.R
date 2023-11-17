
get_cbsa_xwalk <- function(xwalk_url) {
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

describe_acs_vars_yr <- function(year, dataset){
  
  # get acs5 vars and descriptions
  acs5_vars <- load_variables(year = year, dataset = c(dataset), cache = FALSE)
  
  # Separate concept column so its easier to sort through
  acs5_vars <- acs5_vars %>% separate(col = 'concept',
                                      into = c('concept_main','concept_part'),
                                      sep = c(' BY '),
                                      remove = FALSE,
                                      extra = "merge") %>%
    mutate(concept_part = case_when(is.na(concept_part) ~ 'TOTAL',
                                    TRUE ~ as.character(concept_part)))
  
  return(acs5_vars)
}


clean_acs <- function(acs, acs_vars, cbsa_xwalk, state_xwalk) {
  df <- acs %>%
    rename_all(list(tolower)) %>%
    left_join(., acs_vars %>% select(name, label), by = c('variable' = 'name')) %>%
    mutate(label = gsub("^Estimate!!Total[:]*", "", label), # try
           label = gsub("With income:", "", label),
           label = gsub("In labor force", "", label),
           label = gsub("Civilian labor force", "", label),
           label = gsub("Household income the past 12 months \\(in 2019 inflation-adjusted dollars\\) --", "", label),
           label = gsub("", "", label),
           label = gsub("!!|:", "", label)) %>%
    separate(col = 'variable',  
             into = c('variable_group','variable_item'),
             sep = c('_'),
             remove = FALSE,
             extra = "merge") %>%
    mutate(label = case_when(variable_group == 'B19001A' ~ paste0('White alone',' - ',label),
                             variable_group == 'B19001B' ~ paste0('Black or African American alone',' - ',label),
                             variable_group == 'B19001C' ~ paste0('Native American alone',' - ',label),
                             variable_group == 'B19001D' ~ paste0('Asian alone',' - ',label),
                             variable_group == 'B19001E' ~ paste0('Pacific Islander alone',' - ',label),
                             variable_group == 'B19001F' ~ paste0('Some other race alone',' - ',label),
                             variable_group == 'B19001G' ~ paste0('Two or more races',' - ',label),
                             variable_group == 'B19001H' ~ paste0('White alone, not Latino',' - ',label),
                             variable_group == 'B19001I' ~ paste0('Hispanic or Latino',' - ',label),
                             TRUE ~ as.character(label))) %>%
    mutate(group_label = case_when(variable_group == "B02001" ~ 'Race',
                                   variable_group == "B03001" ~ 'Hispanic or Latino',
                                   variable_group == "B08124" ~ 'Occupation',
                                   variable_group == "B08126" ~ 'Industry',
                                   variable_group == "B15003" ~ 'Education attainment',
                                   variable_group == 'B23025' ~ 'Employment status',
                                   variable_group == 'B06001' ~ 'Age',
                                   variable_group == 'B19001' ~ 'Household income',
                                   variable_group == 'B19001A' ~ 'Household income - White alone',
                                   variable_group == 'B19001B' ~ 'Household income - Black or African American alone',
                                   variable_group == 'B19001C' ~ 'Household income - Native American alone',
                                   variable_group == 'B19001D' ~ 'Household income - Asian alone',
                                   variable_group == 'B19001E' ~ 'Household income - Pacific Islander alone',
                                   variable_group == 'B19001F' ~ 'Household income - Some other race alone',
                                   variable_group == 'B19001G' ~ 'Household income - Two or more races',
                                   variable_group == 'B19001H' ~ 'Household income - White alone, not Latino',
                                   variable_group == 'B19001I' ~ 'Household income - Hispanic or Latino'),
           county_fips = str_sub(geoid,1,5)) %>%
    left_join(., state_xwalk, by = c('county_fips'='county_fips')) %>%
    left_join(.,cbsa_xwalk, by = c('county_fips'='county_fips')) %>%
    group_by(geoid, variable_group) %>% mutate(tract_total = sum(estimate)) %>% ungroup() %>%
    group_by(county_fips, variable) %>% mutate(county_estimate = sum(estimate)) %>% ungroup() %>%
    group_by(county_fips, variable_group) %>% mutate(county_total = sum(estimate)) %>% ungroup() %>%
    group_by(cbsa_fips, variable) %>% mutate(cbsa_estimate = sum(estimate)) %>% ungroup() %>%
    group_by(cbsa_fips, variable_group) %>% mutate(cbsa_total = sum(estimate)) %>% ungroup() %>%
    mutate(tract_pct = estimate / tract_total,
           county_pct = county_estimate / county_total,
           cbsa_pct = cbsa_estimate / cbsa_total) %>%
    rename(tract_estimate = estimate,
           tract_fips = geoid) %>%
    select(tract_fips,county_fips,county_name,cbsa_fips,cbsa_title,area_type,central_outlying_county,state_codes,state_fips,state_name,variable,variable_group,variable_item,group_label,label,tract_pct,tract_estimate,moe,tract_total,county_pct,county_estimate,county_total,cbsa_pct,cbsa_estimate,cbsa_total) %>%
    arrange(county_fips, tract_fips, variable) %>%
    mutate_at(vars(tract_pct,county_pct,cbsa_pct), ~replace(., is.nan(.), 0)) %>%
    filter(cbsa_title %in% c("Chicago-Naperville-Elgin, IL-IN-WI",
                             "Madison, WI",
                             "Minneapolis-St. Paul-Bloomington, MN-WI",
                             "Indianapolis-Carmel-Anderson, IN",
                             "Milwaukee-Waukesha, WI"))
  return(df)
}