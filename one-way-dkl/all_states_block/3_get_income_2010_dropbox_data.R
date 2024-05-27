# Author: Ivanna
# Date: 3/22/2024
# Purpose: calculate dkl and save 2010 data for income

pacman::p_load(tidyverse, here, janitor, magrittr, arrow)
source(here("one-way-dkl/3_all_block/helper_functions.R"))

# ---- read in data ----

comparison_df <- read_parquet("E:/acs5_block_2020_data/dkl_income_20_blkgrp_all_states.parquet")

state_xwalk <- read_csv("E:/state_crosswalk.csv") 

cbsa_xwalk_09 <- get_cbsa_xwalk('https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2009/historical-delineation-files/list3.xls', 2009) %>%
  rename(central_outlying_county = county_status)
cbsa_xwalk_20 <- read_csv("E:/cbsa_crosswalk_2020.csv") # 2020 cbsa crosswalk we saved

df_all <- read_csv(here("one-way-dkl/3_all_block/dropbox_data/2010acs_all.csv"),
                   show_col_types = F) %>% 
  clean_names() %>%
  select(geoid, name, city_name, state, id_1, avghinc, starts_with("hinc"), -ends_with("_w")) %>%
  rename(id = id_1)

# ---- clean data ------

df <- df_all %>%
  pivot_longer(starts_with("hinc"),
               names_to = "label",
               values_to = "block_estimate") %>%
  group_by(geoid) %>%
  mutate(block_total = sum(block_estimate)) %>%
  ungroup() %>%
  mutate(
    label = case_when(label == "hinc000" ~ "Less than $10,000",
                      label == "hinc010" ~ "$10,000 to $14,999",
                      label == "hinc015" ~ "$15,000 to $19,999",
                      label == "hinc020" ~ "$20,000 to $24,999",
                      label == "hinc025" ~ "$25,000 to $29,999",
                      label == "hinc030" ~ "$30,000 to $34,999",
                      label == "hinc035" ~ "$35,000 to $39,999",
                      label == "hinc040" ~ "$40,000 to $44,999",
                      label == "hinc045" ~ "$45,000 to $49,999",
                      label == "hinc050" ~ "$50,000 to $59,999", 
                      label == "hinc060" ~ "$60,000 to $74,999",
                      label == "hinc075" ~ "$75,000 to $99,999" ,
                      label == "hinc100" ~ "$100,000 to $124,999",
                      label == "hinc125" ~ "$125,000 to $149,999",
                      label == "hinc150" ~ "$150,000 to $199,999",
                      label == "hinc200" ~ "$200,000 or more"),
    group_label = "Household Income"
  )


# --------- calculate DLK  -----------

# join cbsa info to calculate cbsa-level estimates

join_with_cbsa <- function(df_2010, cbsa_xwalk) {
  df_2010 %>%
    mutate(geoid = str_sub(geoid, 8, 19),
           county_fips = str_sub(geoid,1,5),
           tract = str_sub(geoid,6,11),
           block_group = str_sub(geoid,12,12)) %>%
    left_join(state_xwalk, by = c('county_fips'='county_fips')) %>%
    left_join(cbsa_xwalk, by = c('county_fips'='county_fips')) %>%
    rename(state_codes = state) %>%
    group_by(geoid, group_label) %>% 
    mutate(block_total = sum(block_estimate)) %>% 
    ungroup() %>%
    group_by(county_fips, label) %>% 
    mutate(county_estimate = sum(block_estimate)) %>% 
    ungroup() %>%
    group_by(county_fips, group_label) %>% 
    mutate(county_total = sum(block_estimate)) %>% 
    ungroup() %>%
    group_by(cbsa_fips, label) %>% 
    mutate(cbsa_estimate = sum(block_estimate)) %>% 
    ungroup() %>%
    group_by(cbsa_fips, group_label) %>% 
    mutate(cbsa_total = sum(block_estimate)) %>% 
    ungroup() %>%
    mutate(block_pct = block_estimate / block_total,
           county_pct = county_estimate / county_total,
           cbsa_pct = cbsa_estimate / cbsa_total) %>%
    rename(block_estimate = block_estimate,
           block_fips = geoid) %>%
    select(block_fips,county_fips,county_name,cbsa_fips,cbsa_title,area_type,central_outlying_county,state_codes,
           state_fips,state_name,label,group_label, group_label,label,block_pct,block_estimate,
           block_total,county_pct,county_estimate,county_total,cbsa_pct,cbsa_estimate,cbsa_total) %>%
    arrange(county_fips, block_fips, label) %>%
    mutate_at(vars(block_pct,county_pct,cbsa_pct), ~replace(., is.nan(.), 0))
}

df_agg_20 <- join_with_cbsa(df, cbsa_xwalk_20)
df_agg_09 <- join_with_cbsa(df, cbsa_xwalk_09)


# calculate DKL

calc_dkl <- function(df_agg) {
  df_agg %>%
    mutate(p_ni = block_total / cbsa_total, # Prob of being in block in MSA 
           p_ni_yj = block_estimate / cbsa_estimate, # Prob of being in block among people in bin 
           p_yj = cbsa_estimate / cbsa_total, # Prob of being in bin for everyone in MSA 
           p_yj_ni = block_estimate / block_total) %>%
    # replace all NaN produced from 0/0 to 0
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
    group_by(group_label, block_fips) %>% 
    mutate(dkl_block = sum(dkl_block_j)) %>% 
    ungroup() %>% 
    # Sum DKL bin components
    group_by(group_label, cbsa_fips, label) %>% 
    mutate(dkl_bin = sum(dkl_bin_i )) %>% 
    ungroup()
  
}

df_dkl_20 <- calc_dkl(df_agg_20)
df_dkl_09 <- calc_dkl(df_agg_09)

# --- save ----

write_parquet(df_dkl, "E:/acs5_block_2010_data/dkl_income_10_blkgrp_all_states.parquet")
write_parquet(df_dkl_09, "E:/acs5_block_2010_data/cbsa_10_dkl_income_10_blkgrp_all_states.parquet")






