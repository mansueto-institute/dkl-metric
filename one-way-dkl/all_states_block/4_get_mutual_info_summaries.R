# Purpose: get summaries for each state
# Date: 2/13/2024
# Author: Ivanna

# install.packages("pacman")
pacman::p_load(tidyverse, tidycensus, readxl, magrittr, here, arrow)
source(here("one-way-dkl/3_all_block/helper_functions.R"))

folder_10 <- 'E:/acs5_block_2010_data/'
folder_15 <- 'E:/acs5_block_2015_data/'
folder_20 <- 'E:/acs5_block_2020_data/'

# ---- calculate and safe mutual info datasets -------------------------------

get_mutual_info_by_metro <- function(df) {
  
  # calculate MI by method one: at the block level
  # checks for equivalency between the two methods (block vs bin) are commented below
  # at the end of this script
  
  df_agg <- df %>%
    select(block_fips, group_label, block_total, dkl_block, p_ni, cbsa_title, cbsa_total, state_codes) %>%
    mutate(p_block = block_total / cbsa_total) %>%
    distinct() # unique at block_fips level
  
  block_mi <- df_agg %>%
    group_by(cbsa_title) %>%
    mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_block, p_ni)) %>%
    select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
    distinct()
  
  return(block_mi)
}


save_mi_file <- function(var, yr) {
  
  if (yr == "15") {
    folder = folder_15
  }
  else if ((yr == "20")) {
    folder = folder_20
  }
  else if ((yr == "10")) {
    folder = folder_10
  }
  
  dkl_df <- read_parquet(paste0(folder, paste0("dkl_", var, "_", yr, "_blkgrp_all_states.parquet")))
  mi_df <- get_mutual_info_by_metro(dkl_df)
  write_parquet(mi_df, paste0(folder, paste0("mi_", var, "_", yr, "_blkgrp_all_states.parquet")))
  rm(dkl_df, mi_df)
  
}

save_mi_file("income", "10")
save_mi_file("income", "15")
save_mi_file("income", "20")

save_mi_file("race", "15")
save_mi_file("race", "20")

save_mi_file("empl", "15")
save_mi_file("empl", "20")

save_mi_file("educ", "15")
save_mi_file("educ", "20")


# ---- compare if two methods for calculating mi yield same results ----

# income_15 <- read_parquet(paste0(folder_15, paste0("dkl_", "income", "_", "15", "_blkgrp_all_states.parquet")))
# 
# ## method 1
# income_15_dkl_block <- income_15 %>%
#  select(block_fips, group_label, cbsa_title,  cbsa_total, block_total, state_codes, dkl_block, p_ni) %>%
#  mutate(p_block = block_total / cbsa_total) %>%
#  distinct() # unique at block_fips level
# 
# n_distinct(income_15_dkl_block$cbsa_title) # 934 cbsa w 2015, after using 2020 cbsa it's now 928
# n_distinct(income_15_dkl_block$state_codes) # 50 states
# 
# # now get average dkl by cbsa
# block_avg_15 <- income_15_dkl_block %>%
#  group_by(cbsa_title) %>%
#  mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_block, p_block),
#         avg_dkl_cbsa_pop = round(avg_dkl_cbsa_pop, digits = 2)) %>% # p_ni == p_block estimated above.
#  select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
#  distinct()
# 
# ## checking here that p_ni == p_block:
# # block_avg_15 <- race_15_dkl_block %>%
# #   group_by(cbsa_title) %>%
# #   mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_block, p_block)) %>%
# #   select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
# #   distinct()
# 
# ## method 2
# income_15_dkl_bin <- income_15 %>%
#   select(block_fips, group_label, label, cbsa_title, cbsa_estimate, cbsa_total, state_codes, block_estimate, dkl_bin) %>%
#   mutate(p_bin = block_estimate / cbsa_total) %>%
#   distinct() # unique at block_fips, label and dkl_bin level
# 
# bin_avg <- income_15_dkl_bin %>%
#  group_by(cbsa_title) %>%
#  mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_bin, p_bin),
#         avg_dkl_cbsa_pop = round(avg_dkl_cbsa_pop, digits = 2)) %>%
#  select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
#  distinct()
# 
# sum(bin_avg$avg_dkl_cbsa_pop == block_avg_15$avg_dkl_cbsa_pop) / nrow(bin_avg) # 100% when rounding
# 
# # bring in old ones to compare:
# mi_race_15 <- read_parquet(paste0(folder_15, "mi_race_15_blkgrp_all_states.parquet"))
# mi_race_20 <- read_parquet(paste0(folder_20, "mi_race_20_blkgrp_all_states.parquet"))
# 
# # ---- now 2020 ----
# 
# race_20 <- read_parquet(paste0(folder_20, "dkl_race_20_blkgrp_all_states.parquet"))
# 
# ## method 1
# race_20_dkl_block <- race_20 %>%
#   select(block_fips, group_label, block_total, dkl_block, p_ni, cbsa_title, cbsa_total, state_codes) %>%
#   mutate(p_block = block_total / cbsa_total) %>%
#   distinct() # unique at block_fips level
# 
# # now get average dkl by cbsa
# block_avg_20 <- race_20_dkl_block %>%
#   group_by(cbsa_title) %>%
#   mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_block, p_ni)) %>%
#   select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
#   distinct()
# 
# ## method 2
# race_20_dkl_bin <- race_20 %>%
#   select(block_fips, group_label, label, cbsa_title, cbsa_total, state_codes, block_estimate, dkl_bin) %>%
#   mutate(p_bin = block_estimate / cbsa_total) %>%
#   distinct() # unique at block_fips, label and dkl_bin level
# 
# bin_avg_20_m2 <- race_20_dkl_bin %>%
#   group_by(cbsa_title) %>%
#   mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_bin, p_bin)) %>%
#   select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
#   distinct()
# 
# # compare cols
# mi_20 <- block_avg_20 %>%
#   rename(avg_dkl_cbsa_pop_block = avg_dkl_cbsa_pop) %>%
#   mutate(avg_dkl_cbsa_pop_block = round(avg_dkl_cbsa_pop_block, digits = 2)) %>%
#   left_join(bin_avg_20_m2, by = c("cbsa_title", "state_codes")) %>%
#   rename(avg_dkl_cbsa_pop_bin = avg_dkl_cbsa_pop) %>%
#   mutate(avg_dkl_cbsa_pop_bin = round(avg_dkl_cbsa_pop_block, digits = 2)) %>%
#   mutate(equal = avg_dkl_cbsa_pop_block == avg_dkl_cbsa_pop_bin)
# 
# sum(mi_20$equal) / nrow(mi_20) * 100 # 100%
# 
# 
