#####################################
# Get block group shapefiles for maps
#
# 12/22/2023
#####################################

# install.packages("pacman")

pacman::p_load(tidyverse, sf, tidycensus, here, magrittr)
readRenviron("~/.Renviron")

geom_block_20 <- get_acs(year = 2020, 
                         geography = "block group", 
                         survey = 'acs5', 
                         variables = 'B19001_001', 
                         state = '17', county = '031', geometry = TRUE) %>%
  select(GEOID) %>% 
  st_transform(crs = st_crs(4326)) 

geom_block_15 <- get_acs(year = 2015, 
                         geography = "block group", 
                         survey = 'acs5', 
                         variables = 'B19001_001', 
                         state = '17', county = '031', geometry = TRUE) %>%
  select(GEOID) %>% 
  st_transform(crs = st_crs(4326)) 

community_areas <- st_read('https://data.cityofchicago.org/api/geospatial/cauq-8yn6?method=export&format=GeoJSON') %>% 
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf() %>% 
  select(community)

geom_block_20 %<>%
  st_join(community_areas, left= TRUE, largest = TRUE) %>%
  filter(!is.na(community))

geom_block_15 %<>%
  st_join(community_areas, left= TRUE, largest = TRUE) %>%
  filter(!is.na(community))

st_write(geom_block_15, here("one-way-dkl/data/geom_block_15.geojson"), driver = "GeoJSON", overwrite = TRUE)
st_write(geom_block_20, here("one-way-dkl/data/geom_block_20.geojson"), driver = "GeoJSON", overwrite = TRUE)
st_write(community_areas, here("one-way-dkl/data/community_areas.geojson"), driver = "GeoJSON", overwrite = TRUE)
