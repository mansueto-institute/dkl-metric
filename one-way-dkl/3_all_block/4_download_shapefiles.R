# Purpose: Download shapefiles for DKL map visualizations
# Date: 2/14/2024
# Author: Ivanna

# install.packages("pacman")
pacman::p_load(tidyverse, sf, tidycensus, here, magrittr, tigris)
readRenviron("~/.Renviron")

folder <- 'E:/shapefiles/'

state_codes <- c(
  'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
  'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
  'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
  'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
  'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
)

# ---- 2015
us_block_grps_15 <- map_dfr(state_codes, 
                            ~ tigris::block_groups(state = .x, year = 2015, cb = TRUE))
# save
st_write(us_block_grps_15, paste0(folder, "usa_block_groups_2015.geojson"), driver = "GeoJSON", overwrite = TRUE)

# ---- 2020
us_block_grps_20 <- map_dfr(state_codes, 
                            ~ tigris::block_groups(state = .x, year = 2020, cb = TRUE))

# save
st_write(us_block_grps_20, paste0(folder, "usa_block_groups_2020.geojson"), driver = "GeoJSON", overwrite = TRUE)
