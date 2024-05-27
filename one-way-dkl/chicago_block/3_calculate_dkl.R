##################################
# calculate DKL at the block level
#
# 21/12/2023
##################################

pacman::p_load(tidyverse, arrow, here, stringr, tidycensus, readxl)

options(scipen=9999)

# ---- read in data ----

df_2015 <- read_parquet(here("one-way-dkl/data/clean_acs_block_grp_all_us_data_2015.parquet"))
df_2020 <- read_parquet(here("one-way-dkl/data/clean_acs_block_grp_all_us_data_2020.parquet"))

tract_2020 <- read_parquet(here("one-way-dkl/data/clean_acs_tract_all_us_data_2020.parquet"))


df_15 <- df_2015 %>% 
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


df_20 <- df_2020 %>% 
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

write_parquet(df_15, here("one-way-dkl/data/test_dkl_block_15.parquet"))
write_parquet(df_20, here("one-way-dkl/data/test_dkl_block_20.parquet"))

