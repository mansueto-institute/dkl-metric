# Purpose: get summaries for each state
# Date: 2/13/2024
# Author: Ivanna

# install.packages("pacman")
pacman::p_load(tidyverse, tidycensus, readxl, magrittr, here, arrow)
source(here("one-way-dkl/3_all_block/helper_functions.R"))

folder_15 <- 'E:/acs5_block_2015_data/'
folder_20 <- 'E:/acs5_block_2020_data/'

# ---- calculate and safe mutual info datasets -------------------------------

save_mi_file <- function(var, yr) {
  
  if (yr == "15") {
    folder = folder_15
  }
  else if ((yr == "20")) {
    folder = folder_20
  }
  
  dkl_df <- read_parquet(paste0(folder, paste0("dkl_", var, "_", yr, "_blkgrp_all_states.parquet")))
  mi_df <- get_mutual_info_by_metro(dkl_df)
  write_parquet(mi_df, paste0(folder, paste0("mi_", var, "_", yr, "_blkgrp_all_states.parquet")))
  rm(dkl_df, mi_df)
  
}

save_mi_file("race", "15")
save_mi_file("race", "20")
save_mi_file("income", "15")
save_mi_file("income", "20")
save_mi_file("empl", "15")
save_mi_file("empl", "20")
save_mi_file("educ", "15")
save_mi_file("educ", "20")


# ---- compare if two methods for calculating mi yield same results ----

# ## method 1
# race_15_dkl_block <- race_15 %>%
#   select(block_fips, group_label, cbsa_title,  cbsa_total, block_total, state_codes, dkl_block, p_ni) %>%
#   mutate(p_block = block_total / cbsa_total) %>%
#   distinct() # unique at block_fips level
# 
# n_distinct(race_15_dkl_block$cbsa_title) # 934 metros
# n_distinct(race_15_dkl_block$state_codes) # 50 states
# 
# # now get average dkl by cbsa
# block_avg <- race_15_dkl_block %>%
#   group_by(cbsa_title) %>%
#   mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_block, p_ni)) %>%
#   select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
#   distinct()
# 
# ## method 2
# race_15_dkl_bin <- race_15 %>%
#   select(block_fips, group_label, label, cbsa_title, cbsa_total, state_codes, block_estimate, dkl_bin) %>%
#   mutate(p_bin = block_estimate / cbsa_total) %>%
#   distinct() # unique at block_fips, label and dkl_bin level
# 
# bin_avg <- race_15_dkl_bin %>%
#   group_by(cbsa_title) %>%
#   mutate(avg_dkl_cbsa_pop = weighted.mean(dkl_bin, p_bin)) %>%
#   select(cbsa_title, state_codes, avg_dkl_cbsa_pop) %>%
#   distinct()









