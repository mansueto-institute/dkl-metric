

library(tidyverse)
library(sf)
library(lwgeom)
library(tidycensus)
library(scales)
library(viridis)
library(DT)
library(shiny)
library(ggplot2)
library(readxl)
library(patchwork)

# Read the .Renviron file (only necessary fi you ran census_api_key()
readRenviron("~/.Renviron")

# Explore ACS application ----------------------------------------------------

# Function to launch a mini Shiny app to look up Census variables
explore_acs_vars <- function () { 
  ui <- basicPage(h2("ACS Variable Search"), 
                  tags$style('#display {height:100px; white-space: pre-wrap;}'),
                  verbatimTextOutput('display', placeholder = TRUE),
                  mainPanel(DT::dataTableOutput(outputId = "acs_table", width = '800px'))
  )
  server <- function(input, output, session) {
    output$acs_table= DT::renderDataTable({ 
      acs5_vars <- acs5_vars 
    }, filter = "top", selection = 'multiple', options = list(columnDefs = list( list(className = "nowrap",width = '100px', targets = c(1,2))), pageLength = 20), server = TRUE) 
    selected_index <- reactive({
      acs5_vars %>% slice(input$acs_table_rows_selected) %>% pull(name)
    })
    output$display = renderPrint({
      s = unique(input$acs_table_rows_selected)
      if (length(s)) {cat(paste0("'",selected_index(),"'",collapse = ","))}
    })
  }
  shinyApp(ui, server)
}


# Metro FIPS --------------------------------------------------------------

wd_dev <- '/Users/nm/Desktop'
cbsa_list <- c('35620') #'35620','31080','16980','19100','26420','47900','33100','37980','12060','14460'

# Census Variables --------------------------------------------------------

# Census Variables
acs5_vars <- load_variables(year = 2020, dataset = c('acs5'), cache = FALSE) %>% 
  separate(col = 'concept',  into = c('concept_main','concept_part'), sep = c(' BY '), remove = FALSE,extra = "merge") %>%
  mutate(concept_part = case_when(is.na(concept_part) ~ 'TOTAL', TRUE ~ as.character(concept_part)))

acs5_vars_selected <- c(# Race/ethnicity population 
  'B03002_003','B03002_004','B03002_005','B03002_006','B03002_007','B03002_008','B03002_009','B03002_012',
  # Household income
  'B19001_002', 'B19001_003', 'B19001_004', 'B19001_005', 'B19001_006', 'B19001_007', 'B19001_008', 'B19001_009', 'B19001_010', 'B19001_011', 'B19001_012', 'B19001_013', 'B19001_014', 'B19001_015', 'B19001_016', 'B19001_017',
  # Household income x Race/ethnicity
  'B19001A_002','B19001A_003','B19001A_004','B19001A_005','B19001A_006','B19001A_007','B19001A_008','B19001A_009','B19001A_010','B19001A_011','B19001A_012','B19001A_013','B19001A_014','B19001A_015','B19001A_016','B19001A_017',
  'B19001B_002','B19001B_003','B19001B_004','B19001B_005','B19001B_006','B19001B_007','B19001B_008','B19001B_009','B19001B_010','B19001B_011','B19001B_012','B19001B_013','B19001B_014','B19001B_015','B19001B_016','B19001B_017',
  'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
  'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
  'B19001D_002','B19001D_003','B19001D_004','B19001D_005','B19001D_006','B19001D_007','B19001D_008','B19001D_009','B19001D_010','B19001D_011','B19001D_012','B19001D_013','B19001D_014','B19001D_015','B19001D_016','B19001D_017',
  'B19001E_002','B19001E_003','B19001E_004','B19001E_005','B19001E_006','B19001E_007','B19001E_008','B19001E_009','B19001E_010','B19001E_011','B19001E_012','B19001E_013','B19001E_014','B19001E_015','B19001E_016','B19001E_017',
  'B19001F_002','B19001F_003','B19001F_004','B19001F_005','B19001F_006','B19001F_007','B19001F_008','B19001F_009','B19001F_010','B19001F_011','B19001F_012','B19001F_013','B19001F_014','B19001F_015','B19001F_016','B19001F_017',
  'B19001G_002','B19001G_003','B19001G_004','B19001G_005','B19001G_006','B19001G_007','B19001G_008','B19001G_009','B19001G_010','B19001G_011','B19001G_012','B19001G_013','B19001G_014','B19001G_015','B19001G_016','B19001G_017',
  'B19001H_002','B19001H_003','B19001H_004','B19001H_005','B19001H_006','B19001H_007','B19001H_008','B19001H_009','B19001H_010','B19001H_011','B19001H_012','B19001H_013','B19001H_014','B19001H_015','B19001H_016','B19001H_017',
  # Median Household Income
  'B19013_001') #,'B19013B_001','B19013C_001','B19013D_001','B19013E_001','B19013F_001','B19013G_001','B19013H_001','B19013I_001')

# Build crosswalks and spatial geometry files -----------------------------

# State crosswalk
state_xwalk <- as.data.frame(fips_codes) %>%
  rename(state_fips = state_code,state_codes = state,county_name = county) %>%
  mutate(county_fips = paste0(state_fips,county_code))
state_fips <- unique(state_xwalk$state_fips)[1:51]
state_codes <- unique(state_xwalk$state_codes)[1:51]

# Metro crosswalk
xwalk_url <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls'
tmp_filepath <- paste0(tempdir(), '/', basename(xwalk_url))
download.file(url = paste0(xwalk_url), destfile = tmp_filepath)
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

# County crosswalk
us_county <- get_acs(year = 2020, geography = "county", variables = "B01003_001", geometry = TRUE, keep_geo_vars = TRUE, shift_geo = TRUE)
us_county_cbsa <- us_county %>%
  rename_all(list(tolower)) %>%
  rename(county_fips = geoid,
         county_population = estimate) %>%
  select(county_fips,county_population) %>% 
  left_join(., cbsa_xwalk, by = c('county_fips'='county_fips') ) %>%
  left_join(., state_xwalk, by = c('county_fips'='county_fips') ) %>%
  mutate(area_type = case_when(is.na(area_type) ~ 'Rural',
                               area_type == 'Metropolitan Statistical Area' ~ 'Metro',
                               area_type == 'Micropolitan Statistical Area' ~ 'Micro'),
         central_outlying_county = ifelse(is.na(central_outlying_county), 'Rural', central_outlying_county)) %>%
  select(county_fips,county_code,county_name,county_population,
         cbsa_fips,cbsa_title,area_type,central_outlying_county,
         state_codes,state_fips,state_name) %>%
  mutate(cbsa_fips = coalesce(cbsa_fips, paste0(county_code,state_fips)),
         cbsa_title = coalesce(cbsa_title,paste0('Rest of ',state_codes))) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf() %>%
  group_by(cbsa_fips, area_type) %>%
  mutate(cbsa_population = sum(county_population)) %>%
  ungroup() %>% 
  mutate(metro_rank = dense_rank(desc(cbsa_population)))

# Subset to CBSA  ---------------------------------------------------------

# Subset to states in CBSA list
state_fips_list <- us_county_cbsa %>% 
  filter(cbsa_fips %in% cbsa_list) %>% st_drop_geometry() %>%
  select(state_fips) %>% distinct() %>% pull()

us_county_cbsa_subset <- us_county_cbsa %>%
  filter(cbsa_fips %in% cbsa_list)
  
# Tract Delineations -------------------------------------------------------

filedir <- paste0(tempdir(), '/tracts/')
unlink(filedir, recursive = TRUE)
dir.create(filedir)
for (s in state_fips_list) {
  state_shp <- paste0('https://www2.census.gov/geo/tiger/TIGER2020/TRACT/tl_2020_',s,'_tract.zip')
  download.file(url = state_shp, destfile = paste0(filedir, basename(state_shp)))
  unzip(paste0(filedir,basename(state_shp)), exdir= filedir)
}
list.files(path = filedir)
us_tracts <- st_read(fs::dir_ls(filedir, regexp = "\\.shp$")[1])
for (f in fs::dir_ls(filedir, regexp = "\\.shp$")[-1] ) {
  state_sf <- st_read(f)
  us_tracts <- rbind(us_tracts, state_sf)
}

us_tracts <- us_tracts %>% 
  rename_all(tolower) %>%
  mutate_at(vars(statefp, countyfp, tractce, geoid),list(as.character)) %>%
  mutate(geoid = str_pad(geoid, width=11, side="left", pad="0"),
         statefp = str_pad(statefp, width=2, side="left", pad="0"),
         countyfp = str_pad(countyfp, width=3, side="left", pad="0"),
         tractce = str_pad(tractce, width=6, side="left", pad="0")) %>%
  filter(statefp %in% state_fips) %>% 
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Tract geometries
tract_geometries <- us_tracts %>% 
  mutate(county_fips = str_sub(geoid,1,5),
         pct_water = awater / (awater + aland)) %>%
  filter(pct_water < 1) %>%
  select(geoid, county_fips) %>% 
  left_join(., us_county_cbsa %>% st_drop_geometry() %>% select(county_fips, county_name, cbsa_fips, cbsa_title), by = c('county_fips'='county_fips'))
#filter(county_fips %in% c(us_county_cbsa %>% filter(cbsa_fips %in% cbsa_list) %>% select(county_fips) %>% st_drop_geometry() %>% pull()))

# Road geometries
primary_roads <- tigris::primary_roads() %>% st_transform(crs = st_crs(4326)) %>% st_as_sf() 

# City Delineations -------------------------------------------------------

filedir <- paste0(tempdir(), '/places/')
unlink(filedir, recursive = TRUE)
dir.create(filedir)
for (s in state_fips_list) {
  state_shp <- paste0('https://www2.census.gov/geo/tiger/TIGER2020/PLACE/tl_2020_',s,'_place.zip')
  download.file(url = state_shp, destfile = paste0(filedir, basename(state_shp)))
  unzip(paste0(filedir,basename(state_shp)), exdir= filedir)
}
list.files(path = filedir)
us_places <- st_read(fs::dir_ls(filedir, regexp = "\\.shp$")[1])
for (f in fs::dir_ls(filedir, regexp = "\\.shp$")[-1] ) {
  state_sf <- st_read(f)
  us_places <- rbind(us_places, state_sf)
}

us_places <- us_places %>% 
  rename_all(tolower) %>%
  mutate_at(vars(geoid, statefp, placefp, placens),list(as.character)) %>%
  mutate(geoid = str_pad(geoid, width=7, side="left", pad="0"),
         statefp = str_pad(statefp, width=2, side="left", pad="0"),
         placefp = str_pad(placefp, width=5, side="left", pad="0"),
         placens = str_pad(placens, width=8, side="left", pad="0")) %>%
  filter(statefp %in% state_fips) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

places_url <- 'https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/cities/SUB-EST2020_ALL.csv'
tmp_filepath <- paste0(tempdir(), '/', basename(places_url))
download.file(url = paste0(places_url), destfile = tmp_filepath)
places_pop <- read_csv(tmp_filepath)

places_pop <- places_pop %>%
  rename_all(tolower) %>% 
  filter(sumlev %in% c('061','162','171')) %>%
  select(state, place, name, stname, popestimate2018) %>%
  mutate(state = str_pad(state, width=2, side="left", pad="0"),
         place = str_pad(place, width=5, side="left", pad="0"),
         placeid = paste0(state,place)) %>%
  rename(cityname = name)

us_places <- inner_join(us_places, places_pop, by = c('geoid'='placeid')) %>%
  st_transform(crs = st_crs(4326)) %>%  st_as_sf()

# Largest city in each metro

metro_delineation <- us_county_cbsa_subset %>% select(cbsa_fips, cbsa_title) %>% st_make_valid() %>% 
  group_by(cbsa_fips, cbsa_title) %>% 
  summarize(geometry = st_union(geometry)) %>%
  ungroup()

place_geometries <- us_places %>% st_make_valid() %>%
  st_join(., metro_delineation %>% st_make_valid(), left = TRUE, largest = TRUE, join = st_within) %>% 
  filter(!is.na(cbsa_fips)) %>%
  group_by(cbsa_fips) %>%
  mutate(place_rank = dense_rank(desc(popestimate2018))) %>%
  ungroup() %>%
  filter(place_rank == 1) %>%
  select(geoid, name, popestimate2018, cbsa_fips, cbsa_title)
rm(us_tracts, us_places, us_county, state_xwalk, cbsa_xwalk)


# Download and clean up ACS data -------------------------------------------------------

# Assemble list of states and counties
state_county_list <- us_county_cbsa %>% filter(cbsa_fips %in% cbsa_list) %>% 
  st_drop_geometry() %>% select(state_fips, county_code) %>% as.list() 

# Download data for select states and counties
if (length(state_county_list[[2]]) < length(acs5_vars_selected)) {
  acs_data <- map2_dfr(.x = state_county_list[[1]], .y = state_county_list[[2]], .f = function(x , y) {
    get_acs(year = 2020, geography = "tract", survey = 'acs5',
            variables = acs5_vars_selected,
            state = x, county = y)
  })
  area_water <- map2_dfr(.x = state_county_list[[1]], .y = state_county_list[[2]], .f = function(x , y) {
    tigris::area_water(state = x, county = y, year = 2020) %>% st_transform(crs = st_crs(4326)) %>% st_as_sf() 
  })
}

# Download for all states (for bulk processing / all metros / all tracts)
# acs_data <- map_dfr(.x = state_fips, .f = function(x) {
#   get_acs(year = 2020, geography = "tract", survey = 'acs5',
#           variables = acs5_vars_selected,
#           state = x)
# })
# area_water <- map_dfr(.x = state_fips, .f = function(x) {
#   tigris::area_water(state = x, year = 2020) %>% st_transform(crs = st_crs(4326)) %>% st_as_sf() 
# })

# Clean up ACS data
acs_data_clean <- acs_data %>% 
  rename_all(list(tolower)) %>%
  select(geoid,variable,estimate,moe) %>%
  left_join(., acs5_vars %>% select(name, label), by = c('variable' = 'name')) %>%
  mutate(label  = gsub("Estimate!!Total:", "", label ), 
         label  = gsub("With income:", "", label ),
         label  = gsub("In labor force", "", label ),
         label  = gsub("Civilian labor force", "", label ),
         label  = gsub("Household income the past 12 months \\(in 2020 inflation-adjusted dollars\\) --", "", label),
         label  = gsub("", "", label ),
         label  = gsub("!!|:", "", label),
         label  = gsub("EstimateTotalNot Hispanic or Latino", "", label),
         label  = gsub("EstimateTotal", "", label)) %>%
  separate(col = 'variable',  
           into = c('variable_group','variable_item'),
           sep = c('_'),
           remove = FALSE,
           extra = "merge") %>%
  mutate(variable_supergroup = gsub("[^0-9]$", "", variable_group)) %>%
  mutate(variable_label = case_when(
    variable == 'B19013_001' ~ 'Median household income',
    variable_group %in% c('B11001A') ~ 'White alone',
    variable_group == 'B11001B' | variable %in% c('B03002_004','B19013B_001') ~ 'Black or African American alone',
    variable_group == 'B11001C' | variable %in% c('B03002_005','B19013C_001') ~ 'Native American alone',
    variable_group == 'B11001D' | variable %in% c('B03002_006','B19013D_001') ~ 'Asian alone',
    variable_group == 'B11001E' | variable %in% c('B03002_007','B19013E_001') ~ 'Pacific Islander alone',
    variable_group == 'B11001F' | variable %in% c('B03002_008','B19013F_001') ~ 'Some other race alone',
    variable_group == 'B11001G' | variable %in% c('B03002_009','B19013G_001') ~ 'Two or more races',
    variable_group == 'B11001H' | variable %in% c('B03002_003','B19013H_001') ~ 'White alone, not Hispanic or Latino', 
    variable_group == 'B11001I' | variable %in% c('B03002_012','B19013I_001') ~ 'Hispanic or Latino',
    variable_group %in% c('B19001A','B19101A') ~ paste0('White alone',' - ',label),
    variable_group %in% c('B19001B','B19101B') ~ paste0('Black or African American alone',' - ',label),
    variable_group %in% c('B19001C','B19101C') ~ paste0('Native American alone',' - ',label),
    variable_group %in% c('B19001D','B19101D') ~ paste0('Asian alone',' - ',label),
    variable_group %in% c('B19001E','B19101E') ~ paste0('Pacific Islander alone',' - ',label),
    variable_group %in% c('B19001F','B19101F') ~ paste0('Some other race alone',' - ',label),
    variable_group %in% c('B19001G','B19101G') ~ paste0('Two or more races',' - ',label),
    variable_group %in% c('B19001H','B19101H') ~ paste0('White alone, not Hispanic or Latino',' - ',label), 
    variable_group %in% c('B19001I','B19101I') ~ paste0('Hispanic or Latino',' - ',label),
    TRUE ~ as.character(label))) %>%
  mutate(group_label = case_when(variable_group == "B02001" ~ 'Race',
                                 variable_group == "B03002" ~ 'Race / ethnicity',
                                 variable_group == "B03001" ~ 'Hispanic or Latino',
                                 variable_group == "B08124" ~ 'Occupation',
                                 variable_group == "B08126" ~ 'Industry',
                                 variable_group == "B15003" ~ 'Education attainment',
                                 variable_group == 'B23025' ~ 'Employment status',
                                 variable_group == 'B06001' ~ 'Age',
                                 variable_group == 'B19001' ~ 'Household income', 
                                 variable == 'B19013_001' ~ 'Median household income',
                                 variable %in% c('B19013B_001','B19013C_001','B19013D_001','B19013E_001','B19013F_001','B19013G_001','B19013H_001','B19013I_001') ~ "Race and median household income",
                                 variable_group  == 'B19101' ~ 'Family income',
                                 variable_group %in% c('B11001A', 'B11001B', 'B11001C', 'B11001D', 'B11001E', 'B11001F', 'B11001G', 'B11001H', 'B11001I') ~ 'Race / ethnicity (family)',
                                 variable_group %in% c('B19101A','B19101B','B19101C','B19101D','B19101E','B19101F','B19101G','B19101H','B19101I') ~ 'Race and Family income',             
                                 variable_group %in% c('B19001A','B19001B','B19001C','B19001D','B19001E','B19001F','B19001G','B19001H','B19001I') ~ 'Race and Household income'), 
         county_fips = str_sub(geoid,1,5))

acs_data_clean <- acs_data_clean %>%
  left_join(., us_county_cbsa %>% st_drop_geometry(), by = c('county_fips'='county_fips')) %>%
  mutate(latino_adjustment = case_when(variable_group %in% c('B19001H','B19101H','B11001H') ~ -1*estimate,
                                       variable_group %in% c('B19001A','B19101A','B11001A') ~ estimate,
                                       TRUE ~ as.numeric(0)),
         white_latino_group = case_when(variable_group %in% c('B19001H','B19101H','B11001H') ~ 1,
                                        variable_group %in% c('B19001A','B19101A','B11001A') ~ 1,
                                        TRUE ~ as.numeric(0))) %>% 
  group_by(geoid, white_latino_group, variable_supergroup, variable_item) %>%
  mutate(latino_estimate = sum(latino_adjustment)) %>%
  ungroup() %>%
  mutate(estimate2 = estimate,
         estimate2 = case_when(variable_group %in% c('B19001A','B19101A','B11001A') ~ latino_estimate,
                               TRUE ~ as.numeric(estimate2)),
         variable_label = case_when(variable_group %in% c('B19001A','B19101A') ~ gsub('White alone - ','Hispanic or Latino alone - ',variable_label),
                                    variable_group == 'B11001A' ~ gsub('White alone','Hispanic or Latino alone', variable_label),
                                    TRUE ~ as.character(variable_label))) %>%
  rename(tract_estimate = estimate2, tract_fips = geoid) %>%
  select(tract_fips, variable, variable_group, variable_item, tract_estimate, moe, variable_supergroup, variable_label, group_label, county_fips, state_codes, state_fips, state_name, county_code, county_name, cbsa_fips, cbsa_title, area_type, central_outlying_county) 
  
acs_data_clean <- acs_data_clean %>%
  mutate(variable_label_short = variable_label,
         variable_label_short = str_replace(variable_label, "Less than \\$10,000", '< $10K'),
         variable_label_short = str_replace(variable_label_short, "Less than \\$10,000", '< $10K'),
         variable_label_short = str_replace(variable_label_short, "\\$10,000 to \\$14,999", '$10-14K'),
         variable_label_short = str_replace(variable_label_short, "\\$15,000 to \\$19,999", '$15-19K'),
         variable_label_short = str_replace(variable_label_short, "\\$20,000 to \\$24,999", '$20-24K'),
         variable_label_short = str_replace(variable_label_short, "\\$25,000 to \\$29,999", '$25-29K'),
         variable_label_short = str_replace(variable_label_short, "\\$30,000 to \\$34,999", '$30-34K'),
         variable_label_short = str_replace(variable_label_short, "\\$35,000 to \\$39,999", '$35-39K'),
         variable_label_short = str_replace(variable_label_short, "\\$40,000 to \\$44,999", '$40-44K'),
         variable_label_short = str_replace(variable_label_short, "\\$45,000 to \\$49,999", '$45-49K'),
         variable_label_short = str_replace(variable_label_short, "\\$50,000 to \\$59,999", '$50-59K'),
         variable_label_short = str_replace(variable_label_short, "\\$60,000 to \\$74,999", '$60-74K'),
         variable_label_short = str_replace(variable_label_short, "\\$75,000 to \\$99,999", '$75-99K'),
         variable_label_short = str_replace(variable_label_short, "\\$100,000 to \\$124,999", '$100-124K'),
         variable_label_short = str_replace(variable_label_short, "\\$125,000 to \\$149,999", '$125-149K'),
         variable_label_short = str_replace(variable_label_short, "\\$150,000 to \\$199,999", '$150-199K'),
         variable_label_short = str_replace(variable_label_short, "\\$200,000 or more", '> $200K'),
         variable_label_short = str_replace(variable_label_short, "White alone, not Hispanic or Latino", 'White'),
         variable_label_short = str_replace(variable_label_short, "Black or African American alone", 'Black'),
         variable_label_short = str_replace(variable_label_short, "Hispanic or Latino alone", 'Latino'),
         variable_label_short = str_replace(variable_label_short, "Hispanic or Latino", 'Latino'),
         variable_label_short = str_replace(variable_label_short, "Asian alone", 'Asian'),
         variable_label_short = str_replace(variable_label_short, "Some other race alone", 'Other race'),
         variable_label_short = str_replace(variable_label_short, "Two or more races", '2+ races'),
         variable_label_short = str_replace(variable_label_short, "Native American alone", 'Native American'),
         variable_label_short = str_replace(variable_label_short, "Pacific Islander alone", 'Pacific Islander'))


# Calculate DKL -----------------------------------------------------------

# DKL 1 Dimension
acs_dkl_1 <- acs_data_clean %>%
  filter(group_label %in% c('Race / ethnicity','Household income')) %>% 
  group_by(tract_fips, variable_group) %>% mutate(tract_total = sum(tract_estimate)) %>% ungroup() %>%
  group_by(county_fips, variable) %>% mutate(county_estimate = sum(tract_estimate)) %>% ungroup() %>%
  group_by(county_fips, variable_group) %>% mutate(county_total = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, variable) %>% mutate(cbsa_estimate = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, variable_group) %>% mutate(cbsa_total = sum(tract_estimate)) %>% ungroup() %>%
  mutate(tract_pct = tract_estimate / tract_total,
         county_pct = county_estimate / county_total,
         cbsa_pct = cbsa_estimate / cbsa_total) %>%
  select(tract_fips,county_fips,county_name,cbsa_fips,cbsa_title,area_type,central_outlying_county,state_codes,state_fips,state_name,variable,variable_group,variable_item,group_label,variable_label,tract_pct,tract_estimate,moe,tract_total,county_pct,county_estimate,county_total,cbsa_pct,cbsa_estimate,cbsa_total) %>%
  arrange(county_fips, tract_fips, variable) %>%
  mutate_at(vars(tract_pct,county_pct,cbsa_pct), ~replace(., is.nan(.), 0))  %>% 
  mutate(p_ni = tract_total / cbsa_total, # Prob of being in tract in MSA 
         p_ni_yj = tract_estimate / cbsa_estimate, # Prob of being in tract among people in bin 
         p_yj = cbsa_estimate / cbsa_total, # Prob of being in bin for everyone in MSA 
         p_yj_ni = tract_estimate / tract_total) %>% # Prob of being in bin among people in tract 
  mutate_at(vars(p_ni,p_ni_yj,p_yj,p_yj_ni), ~replace(., is.nan(.), 0)) %>%
  mutate(dkl_log_i = log2(p_yj_ni / p_yj), # share of income in tract relative to share of income in metro
         djl_log_j = log2(p_ni_yj / p_ni) # tract share of metro bin relative to share of tract in metro
  ) %>%
  mutate_at(vars(dkl_log_i, djl_log_j), ~replace(., is.infinite(.), 0)) %>%
  mutate_at(vars(dkl_log_i, djl_log_j), ~replace(., is.nan(.), 0)) %>%
  mutate(dkl_tract_j = p_yj_ni * dkl_log_i, # DKL tract component
         dkl_bin_i = p_ni_yj * djl_log_j) %>% # DKL bin component
  group_by(variable_group, tract_fips) %>% 
  mutate(dkl_tract = sum(dkl_tract_j)) %>% 
  ungroup() %>% # Sum DKL tract components
  group_by(variable_group, cbsa_fips, variable) %>% 
  mutate(dkl_bin = sum(dkl_bin_i )) %>% 
  ungroup() %>% # Sum DKL bin components
  select(tract_fips,variable_group,group_label,dkl_tract) %>% 
  distinct()

# DKL 2 Dimensions
acs_dkl_2 <- acs_data_clean %>%
  filter(group_label %in% c('Race and Household income')) %>% 
  separate(col = 'variable_label',  into = c('label_race','label_income'), sep = c(' - '), remove = FALSE, extra = "merge") %>% 
  group_by(cbsa_fips, group_label, label_race) %>%
  mutate(cbsa_estimate_race = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, group_label, label_income) %>%
  mutate(cbsa_estimate_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, group_label, variable_label) %>%
  mutate(cbsa_estimate_race_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, group_label) %>%
  mutate(cbsa_total = sum(tract_estimate)) %>% ungroup() %>%
  group_by(tract_fips, group_label, label_race) %>%
  mutate(tract_estimate_race = sum(tract_estimate)) %>%  ungroup() %>%
  group_by(tract_fips, group_label, label_income) %>%
  mutate(tract_estimate_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(tract_fips, group_label, variable_label) %>%
  mutate(tract_estimate_race_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(tract_fips, group_label) %>%
  mutate(tract_total = sum(tract_estimate)) %>% ungroup() %>%
  mutate(p_yj = cbsa_estimate_race / cbsa_total,
         p_zk = cbsa_estimate_income / cbsa_total,
         p_yjzk = cbsa_estimate_race_income / cbsa_total,
         p_yj_ni = tract_estimate_race / tract_total,
         p_zk_ni = tract_estimate_income / tract_total,
         p_yjzk_ni = tract_estimate_race_income / tract_total) %>%
  mutate_at(vars(p_yj, p_zk, p_yjzk, p_yj_ni, p_zk_ni, p_yjzk_ni), ~replace(., is.nan(.), 0)) %>%
  mutate(dkl_jz_log = log2((p_yj_ni/p_yj) * (p_zk_ni/p_zk) * ((p_yj*p_zk) / p_yjzk ) * (p_yjzk_ni / (p_yj_ni * p_zk_ni ))))  %>%
  mutate_at(vars(dkl_jz_log), ~replace(., is.infinite(.), 0)) %>%
  mutate_at(vars(dkl_jz_log), ~replace(., is.nan(.), 0)) %>%
  group_by(tract_fips, group_label) %>% 
  mutate(dkl_tract = sum(p_yjzk_ni * dkl_jz_log)) %>% ungroup() %>%
  select(tract_fips,variable_supergroup,group_label,dkl_tract) %>% distinct() %>%
  rename(variable_group = variable_supergroup)

# DKL Combined
acs_dkl <- rbind(acs_dkl_1,acs_dkl_2)
rm(acs_dkl_1,acs_dkl_2)

# Build analytical files --------------------------------------------------

# Remove water areas from metro and city tract geometries
msa_tract <- tract_geometries %>% filter(cbsa_fips %in% cbsa_list) %>% st_make_valid()
water_outline <- st_crop(area_water %>% st_make_valid() , y = st_bbox(msa_tract)) %>% 
  filter(AWATER >= 1000000) %>% st_union() %>% st_transform(crs = st_crs(4326)) %>% st_as_sf() 
msa_tract <- msa_tract %>% st_difference(., water_outline) %>% st_make_valid() 
city_outline <- place_geometries%>% filter(cbsa_fips %in% cbsa_list) %>% select(geoid, name) %>% st_make_valid() 
city_tract <- st_intersection(x = msa_tract, y = city_outline)
msa_roads <- st_crop(primary_roads, y = st_bbox(msa_tract))
city_roads <- st_crop(primary_roads, y = st_bbox(city_tract))

# Race map
acs_race_map <- acs_data_clean %>% 
  mutate(race_label = case_when(variable_label == "White alone, not Hispanic or Latino" ~ "White",
                                variable_label == "Black or African American alone" ~ "Black",
                                variable_label == "Hispanic or Latino" ~ "Latino",
                                variable_label == "Asian alone" ~ "Asian",
                                variable_label == "Pacific Islander alone" ~ "Asian",
                                variable_label == "Native American alone" ~ "Other",
                                variable_label == "Some other race alone" ~ "Other",
                                variable_label == "Two or more races" ~ "Other",
                                TRUE ~ as.character("Other"))) %>%
  group_by(tract_fips, variable_group, race_label, variable_supergroup) %>% 
  summarize_at(vars(tract_estimate), list(sum)) %>% #, na.rm = TRUE
  ungroup() %>%
  group_by(tract_fips, variable_group) %>% 
  mutate(tract_total = sum(tract_estimate)) %>% 
  ungroup() %>%
  filter(variable_supergroup == 'B03002') %>% 
  mutate(tract_pct = tract_estimate / tract_total,
         tract_pct = ifelse(is.nan(tract_pct), 0, tract_pct),
         tract_pct_scale = ifelse(tract_pct > .5, 1, (tract_pct^1.5 - min(tract_pct))/(.5 - min(tract_pct))))

acs_race_map <- city_tract %>% select(geoid) %>% 
  left_join(., acs_race_map, by = c('geoid'='tract_fips'))
acs_race_map$race_label <- factor(x = acs_race_map$race_label, levels = c("White","Black","Latino", "Asian","Other"))

# Income map
acs_income_map <- acs_data_clean %>% filter(group_label == 'Median household income') %>%
  mutate(tract_estimate = replace_na(tract_estimate, 0))
acs_income_map <- city_tract %>% select(geoid) %>% left_join(., acs_income_map, by = c('geoid'='tract_fips'))

#city_fips <- city_tract %>% st_drop_geometry() %>% select(geoid) %>% pull()

# Residual 
dkl_residual <- acs_dkl %>% 
  pivot_wider(id_cols = c(tract_fips),
              names_from = c(group_label), 
              values_from = c(dkl_tract)) %>%
  mutate(residual = `Race and Household income` - `Race / ethnicity` - `Household income`) %>%
  select_all(~gsub("\\s+|\\.|\\/", "_", .)) %>%
  select_all(~gsub("__", "_", .)) %>%
  select_all(~gsub("__", "_", .)) %>%
  rename_all(list(tolower))

# Race and Household Income Demographics
acs_demos_race_and_household_income <- acs_data_clean %>% filter(group_label %in% c('Race and Household income')) %>% 
  separate(col = 'variable_label_short',  into = c('label_race','label_income'), sep = c(' - '), remove = FALSE, extra = "merge") %>%
  left_join(., dkl_residual, by = c('tract_fips'='tract_fips')) %>%
  mutate(tract_estimate_dkl = tract_estimate*race_and_household_income) %>%
  group_by(label_race, label_income) %>% summarize_at(vars(tract_estimate, tract_estimate_dkl), list(sum), na.rm = TRUE) %>% ungroup() %>%
  mutate(tract_estimate_dkl = tract_estimate_dkl / tract_estimate) %>%
  group_by(label_income) %>% mutate(tract_estimate_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(label_race) %>% mutate(tract_estimate_race = sum(tract_estimate)) %>% ungroup() %>%
  mutate(tract_share = tract_estimate/tract_estimate_income) 

income_levels <- c('< $10K','$10-14K','$15-19K','$20-24K','$25-29K','$30-34K','$35-39K','$40-44K','$45-49K','$50-59K','$60-74K','$75-99K','$100-124K','$125-149K','$150-199K','> $200K')
race_levels <- c("White","Black","Latino","Asian","2+ races","Native American","Pacific Islander","Other race")
acs_demos_race_and_household_income$label_income <- factor(x = acs_demos_race_and_household_income$label_income, levels = income_levels)
acs_demos_race_and_household_income$label_race <- factor(x = acs_demos_race_and_household_income$label_race, levels = race_levels)

acs_demos_race_and_household_income <- acs_demos_race_and_household_income %>%
  arrange(label_income, factor(label_race, levels = rev(race_levels))) %>%
  group_by(label_income) %>%
  mutate(pos_id_share = (cumsum(tract_share) - 0.5*tract_share)) %>%
  ungroup() 

# Race or Income Demographics
acs_demos_race_or_household_income <- acs_data_clean %>% filter(group_label %in% c('Race / ethnicity','Household income')) %>% 
  left_join(., dkl_residual, by = c('tract_fips'='tract_fips')) %>%
  mutate(tract_estimate_dkl = case_when(group_label == 'Race / ethnicity' ~ race_ethnicity,
                                        group_label == 'Household income' ~ household_income)) %>%
  mutate(tract_estimate_dkl = tract_estimate*tract_estimate_dkl) %>%
  group_by(group_label, variable_label_short) %>% summarize_at(vars(tract_estimate, tract_estimate_dkl), list(sum), na.rm = TRUE) %>% ungroup() %>%
  mutate(tract_estimate_dkl = tract_estimate_dkl / tract_estimate) %>%
  group_by(group_label) %>% mutate(tract_estimate_total = sum(tract_estimate)) %>% ungroup() %>%
  mutate(tract_share = tract_estimate/tract_estimate_total) 

race_income_levels <- c('< $10K','$10-14K','$15-19K','$20-24K','$25-29K','$30-34K','$35-39K','$40-44K','$45-49K','$50-59K','$60-74K','$75-99K','$100-124K','$125-149K','$150-199K','> $200K',race_levels)
acs_demos_race_or_household_income$variable_label_short <- factor(x = acs_demos_race_or_household_income$variable_label_short, levels = race_income_levels)

acs_demos_race_or_household_income <- acs_demos_race_or_household_income %>%
  arrange(group_label, factor(variable_label_short, levels = rev(race_income_levels ))) %>%
  group_by(group_label) %>%
  mutate(pos_id_share = (cumsum(tract_share) - 0.5*tract_share)) %>%
  ungroup() 

# Build visualizations ----------------------------------------------------


# Visualizations of Tracts
theme_map <- theme(legend.title = element_text(size = 8, face='bold'),
                   legend.text=element_text(size=7.5),
                   legend.position = 'right',
                   legend.margin=margin(c(0,0,0,0)),
                   panel.grid.major = element_blank(), 
                   panel.grid.minor = element_blank(),
                   axis.text = element_blank(),
                   plot.margin=unit(c(t=0,r=0,b=0,l=0), "mm"),
                   plot.subtitle = element_blank(),
                   text = element_text(color = "#0a0a0a"))

# Race / ethnicity
pr_msa <- ggplot(msa_tract %>% left_join(., acs_dkl %>% filter(group_label == 'Race / ethnicity'), by = c('geoid'='tract_fips')), 
                 aes(fill = dkl_tract , color =  dkl_tract)) +
  geom_sf() + scale_fill_viridis(name = 'DKL') + scale_color_viridis(name = 'DKL') + 
  geom_sf(data = msa_roads, color='white', fill = 'white', size = .05) +
  labs(subtitle = 'Race/ethnicity') +
  theme_void() + theme_map + theme(legend.position = 'none', plot.subtitle = element_text(size = 13, hjust = 0.01, vjust = 0, face = 'bold', color = "#0a0a0a" ))

pr_city <- ggplot(city_tract %>% left_join(., acs_dkl %>% filter(group_label == 'Race / ethnicity'), by = c('geoid'='tract_fips')), 
                  aes(fill = dkl_tract , color =  dkl_tract)) +
  geom_sf() + scale_fill_viridis(name = 'DKL') + scale_color_viridis(name = 'DKL') + 
  geom_sf(data = city_roads, color='white', fill = 'white', size = .15) +
  labs(subtitle = city_tract %>% st_drop_geometry() %>% select(name) %>% distinct() %>% pull()) +
  theme_void() + theme_map

pr_map <- ggplot(acs_race_map) +
  geom_sf(aes(fill = race_label,  alpha = tract_pct_scale), color = 'white', size = .02) + 
  scale_fill_manual(name = '', values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#FEFEDF')) +
  geom_sf(data = city_roads, color='white', fill = 'white', size = .05) +
  theme_void() + 
  scale_alpha(guide = 'none') + theme_map

pr_combo <- (( pr_msa + pr_city + plot_layout(ncol = 2, guides = "collect")) | pr_map ) #+ plot_layout(widths = c(2, 1)) 
#ggsave(plot = pr_combo, filename = '/Users/nm/Desktop/nyc_r.png', height = 3, width = 10)
pr_combo

# Household income
phi_msa <- ggplot(msa_tract %>% left_join(., acs_dkl %>% filter(group_label == 'Household income'), by = c('geoid'='tract_fips')), 
                  aes(fill = dkl_tract , color =  dkl_tract)) +
  geom_sf() + scale_fill_viridis(name = 'DKL') + scale_color_viridis(name = 'DKL') +
  geom_sf(data = msa_roads, color='white', fill = 'white', size = .05) +
  #labs(subtitle = msa_tract %>% st_drop_geometry() %>% select(cbsa_title) %>% distinct() %>% pull() %>% gsub(', ',',\n',.) ) +
  labs(subtitle = 'Household income') + 
  theme_void() + theme_map + theme(legend.position = 'none', plot.subtitle = element_text(size = 13, hjust = 0.01, vjust = 0, face = 'bold', color = "#0a0a0a" ))

phi_city <- ggplot(city_tract %>% left_join(., acs_dkl %>% filter(group_label == 'Household income'), by = c('geoid'='tract_fips')), 
                   aes(fill = dkl_tract , color =  dkl_tract)) +
  geom_sf() + scale_fill_viridis(name = 'DKL') + scale_color_viridis(name = 'DKL') +
  geom_sf(data = city_roads, color='white', fill = 'white', size = .15) +
  labs(subtitle = city_tract %>% st_drop_geometry() %>% select(name) %>% distinct() %>% pull()) +
  theme_void() + theme_map

phi_map <- ggplot(acs_income_map) +
  geom_sf(aes(fill = tract_estimate), color = 'white', size = .05) + 
  scale_fill_viridis(name = 'Median', option = 'magma', direction = -1, label = dollar_format(scale = .001,suffix='K')) + 
  geom_sf(data = city_roads, color='white', fill = 'white', size = .05) +
  theme_minimal() + theme_map

phi_combo <- (( phi_msa + phi_city + plot_layout(ncol = 2, guides = "collect")) | phi_map ) # + plot_layout(widths = c(2, 1)) 
#ggsave(plot = phi_combo, filename = '/Users/nm/Desktop/nyc_hi.png', height = 3, width = 10)

# Race and household income
prhi_msa <- ggplot(msa_tract %>% left_join(., acs_dkl %>% filter(group_label == 'Race and Household income'), by = c('geoid'='tract_fips')), 
                   aes(fill = dkl_tract, color = dkl_tract)) +
  geom_sf() + scale_fill_viridis(name = 'DKL') + scale_color_viridis(name = 'DKL') +
  geom_sf(data = msa_roads, color='white', fill = 'white', size = .05) +
  labs(subtitle = 'Race/ethnicity and household income') +
  theme_void() + theme_map + theme(legend.position = 'none', plot.subtitle = element_text(size = 13, hjust = 0.01, vjust = 0, face = 'bold', color = "#0a0a0a"  ))

prhi_city <- ggplot(city_tract %>% left_join(., acs_dkl %>% filter(group_label == 'Race and Household income'), by = c('geoid'='tract_fips')), 
                    aes(fill = dkl_tract, color = dkl_tract)) +
  geom_sf() + scale_fill_viridis(name = 'DKL') + scale_color_viridis(name = 'DKL') +
  geom_sf(data = city_roads, color='white', fill = 'white', size = .05) +
  theme_void() + theme_map

presid_city <- ggplot(city_tract %>% left_join(., dkl_residual, by = c('geoid'='tract_fips')), 
                      aes(fill = residual, color = residual)) +
  geom_sf() + 
  scale_fill_viridis(option = 'plasma', name = '2-way\nResidual', direction = -1) + 
  scale_color_viridis(option = 'plasma', name = '2-way\nResidual', direction = -1) +
  geom_sf(data = city_roads, color='white', fill = 'white', size = .05) +
  theme_void() + theme_map

prhi_combo <- (( prhi_msa + prhi_city + plot_layout(ncol = 2, guides = "collect")) | presid_city ) #+ plot_layout(widths = c(2, 1)) 
# ggsave(plot = prhi_combo, filename = '/Users/nm/Desktop/nyc_rhi.png', height = 3, width = 10)
prhi_combo 

rm(pr_msa, pr_city, pr_map)
rm(phi_msa, phi_city, phi_map)
rm(prhi_msa, prhi_city, presid_city)

# Combine maps
map_combo <- (pr_combo / phi_combo / prhi_combo) + 
  plot_annotation(title = msa_tract %>% st_drop_geometry() %>% select(cbsa_title) %>% distinct() %>% pull()) & 
  theme(plot.title = element_text(face = 'bold',color = "#0a0a0a"  ))

map_combo
city_name <- city_tract %>% st_drop_geometry() %>% select(name) %>% distinct() %>% pull()

### TAKES A COUPLE MINUTES
ggsave(plot = map_combo, filename = paste0(wd_dev,'/',city_name,' Maps.png'), height = 10, width = 10, dpi = 300)

# Demographics
p_bar1 <- ggplot(acs_demos_race_and_household_income) +
  geom_bar(aes(x = label_income, y = tract_estimate, fill = label_race), 
           color = 'white', stat="identity") + coord_flip() +
  scale_fill_manual(values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#845EC2','#FF6F91','#00D2FC','#008F7A','#00C0A3')) + 
  theme_bw() +
  scale_y_continuous(labels = label_comma(scale = .001, accuracy = 1, suffix='K'), expand = c(.02, 0)) +
  geom_text(data = acs_demos_race_and_household_income %>% select(label_income, tract_estimate_income) %>% distinct(), 
            aes(x = label_income, y = tract_estimate_income, label= comma(tract_estimate_income, scale = .001, accuracy =1, suffix = 'K') ), 
            hjust = 1,   fontface = "bold", size = 2.5) +
  labs(subtitle = '') + xlab('Household income') + ylab('Households\n(thousands)') +
  theme(legend.title = element_blank(), 
        #legend.position = 'none',
        # axis.ticks.y = element_blank(),
        # axis.title.y = element_blank(),
        # axis.text.y = element_blank(),
        axis.title.x = element_text(size = 8),
        text = element_text(color = "#0a0a0a" ))

p_bar2 <- ggplot(acs_demos_race_and_household_income) +
  geom_bar(aes(x = label_income, y = tract_share, fill = label_race), 
           color = 'white', stat="identity") + coord_flip() +
  scale_fill_manual(values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#845EC2','#FF6F91','#00D2FC','#008F7A','#00C0A3')) + 
  theme_bw() +
  scale_y_continuous(labels = scales::percent, expand = c(.035, 0)) +
  geom_text(aes(label=ifelse(tract_share >= 0.12, paste0(round(tract_share*100,0),"%"),""), 
                y = pos_id_share, x = label_income), fontface = "bold", size = 3) +
  labs(subtitle = '') + xlab('Household income') + ylab('Households\n(percent)') +
  theme(legend.title = element_blank(), 
        #legend.position = 'none',
        axis.title.x = element_text(size = 8),
        axis.title.y = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        text = element_text(color = "#0a0a0a" ))

p_bar3 <- ggplot(acs_demos_race_or_household_income %>% filter(group_label == 'Race / ethnicity')) +
  geom_bar(aes(x = '', y = tract_share, fill = variable_label_short), color = 'white', stat="identity") + 
  scale_fill_manual(values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#845EC2','#FF6F91','#00D2FC','#008F7A','#00C0A3')) + 
  theme_bw() + 
  scale_x_discrete(expand=c(0, 0)) + 
  scale_y_continuous(labels = scales::percent, expand = c(0, 0)) +
  geom_text(aes(label=ifelse(tract_share >= 0.10, paste0(round(tract_share*100,0),"%\n(",comma(tract_estimate/1000000, accuracy = 0.1),'M)'),""), 
                y = pos_id_share, x = ''),  fontface = "bold", size = 2.5) +
  labs(subtitle = '') + xlab('Population\n(percent)') + ylab('Race / ethnicity') +
  theme(legend.title = element_blank(), 
        axis.title.x = element_text(size = 8),
        axis.ticks.x = element_blank(),
        plot.margin=unit(c(t=0,r=0,b=0,l=0), "mm"),
        text = element_text(color = "#0a0a0a" ))

p_dot_race_income <- ggplot(acs_demos_race_and_household_income) +
  geom_point(aes(x = tract_estimate_dkl, y = label_income, size = tract_estimate, color = label_race, fill = label_race), 
             alpha = .8) + scale_size_area(labels = label_comma(scale = .001,suffix='K')) +
  scale_fill_manual(values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#845EC2','#FF6F91','#00D2FC','#008F7A','#00C0A3'))+
  scale_color_manual(values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#845EC2','#FF6F91','#00D2FC','#008F7A','#00C0A3')) +
  theme_bw() +
  labs(subtitle = '') + ylab('Household income') + xlab('DKL Race and household income\n(household weighted average)') +
  guides(color=FALSE, fill = FALSE) +
  theme(legend.title = element_blank(), 
        axis.title.x = element_text(size = 8),
        legend.position = c("bottom"),
        plot.margin=unit(c(t=0,r=0,b=0,l=0), "mm"),
        legend.margin=margin(c(0,0,0,0)),
        text = element_text(color = "#0a0a0a"  ))

p_dot_race <- ggplot(acs_demos_race_or_household_income %>% filter(group_label == 'Race / ethnicity')) +
  geom_point(aes(x = tract_estimate_dkl, y = '', size = tract_estimate, color = variable_label_short, fill = variable_label_short),
             alpha = .8) + scale_size_area(labels = label_comma(scale = .000001,suffix='M', accuracy= 1)) +
  scale_fill_manual(values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#845EC2','#FF6F91','#00D2FC','#008F7A','#00C0A3'))+
  scale_color_manual(values = c("#009EFA",'#F77552',"#49DEA4","#ffc425",'#845EC2','#FF6F91','#00D2FC','#008F7A','#00C0A3')) +
  theme_bw() +
  labs(subtitle = '') + ylab('') + xlab('DKL Race (population weighted average)') +
  guides(color=FALSE, fill = FALSE) +
  theme(legend.title = element_blank(), 
        axis.title.x = element_text(size = 8),
        axis.ticks.y = element_blank(),
        legend.position = c("top"),
        plot.margin=unit(c(t=0,r=0,b=0,l=0), "mm"),
        legend.margin=margin(c(0,0,0,0)),
        text = element_text(color = "#0a0a0a" ))

p_dot_income <- ggplot(acs_demos_race_or_household_income %>% filter(group_label == 'Household income')) +
  geom_point(aes(x = tract_estimate_dkl, y = variable_label_short, size = tract_estimate),
             alpha = .8) + scale_size_area(labels = label_comma(scale = .001,suffix='K')) +
  theme_bw() +
  labs(subtitle = '') + ylab('') + xlab('DKL Household income\n(household weighted average)') +
  guides(color=FALSE, fill = FALSE) +
  theme(legend.title = element_blank(), 
        axis.title.x = element_text(size = 8),
        axis.title.y = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        legend.position = c("bottom"),
        plot.margin=unit(c(t=0,r=0,b=0,l=0), "mm"),
        legend.margin=margin(c(0,0,0,0)),
        text = element_text(color = "#0a0a0a" ))

layout1 <- "
AAA###
BBBCCC
BBBCCC
BBBCCC
BBBCCC
BBBCCC
"
p_dots <- (p_dot_race + p_dot_race_income + p_dot_income + plot_layout(design = layout1)) 

no_y <- theme(axis.title.y = element_blank(), axis.text.y = element_blank(), axis.ticks.y = element_blank())
p_dots_demos <- (p_dot_race_income | ((p_bar1 + no_y) + p_bar2 + p_bar3 + plot_layout(design = "AAAABBBBC", guides = "collect"))) +
  plot_layout(design = "AAABBBBBBBB", ncol = 2) &
  theme(legend.position = 'bottom',
        legend.box.margin = margin(0, 0, 0, 0),
        legend.margin=margin(c(0,0,0,0))) 

p_demos <- (p_bar1 + p_bar2 + p_bar3 + plot_layout(design = "AAAABBBBC", guides = "collect")) &
  theme(legend.position = 'bottom',
        legend.box.margin = margin(0, 0, 0, 0),
        legend.margin=margin(c(0,0,0,0))) 

ggsave(plot = p_dots, filename = paste0(wd_dev,'/',city_name,' Dots.png'), height = 5.5, width = 7)
ggsave(plot = p_dots_demos, filename = paste0(wd_dev,'/',city_name,' Dots Demos.png'), height = 4, width = 10)
ggsave(plot = p_demos, filename = paste0(wd_dev,'/',city_name,' Demos.png'), height = 4, width = 7)

rm(p_bar1, p_bar2, p_bar3)


#explore_acs_vars()
#B19064_001
#B19301_001
#B25070_001 'B25070_001','B25070_002','B25070_003','B25070_004','B25070_005','B25070_006','B25070_007','B25070_008','B25070_009','B25070_010','B25071_001','B25092_001','B25092_002','B25092_003','B29004_001'
# 'B19301A_001','B19301B_001','B19301C_001','B19301D_001','B19301E_001','B19301F_001','B19301G_001','B19301H_001','B19301I_001'



# # Family race / ethnicity
# 'B11001A_002', 'B11001B_002', 'B11001C_002', 'B11001D_002', 'B11001E_002', 'B11001F_002', 'B11001G_002', 'B11001H_002', #'B11001I_002', 
# # Family income
# 'B19101_002', 'B19101_003', 'B19101_004', 'B19101_005', 'B19101_006', 'B19101_007', 'B19101_008', 'B19101_009', 'B19101_010', 'B19101_011', 'B19101_012', 'B19101_013', 'B19101_014', 'B19101_015', 'B19101_016', 'B19101_017',
# # Family income x Race/ethnicity
# 'B19101A_002', 'B19101A_003', 'B19101A_004', 'B19101A_005', 'B19101A_006', 'B19101A_007', 'B19101A_008', 'B19101A_009', 'B19101A_010', 'B19101A_011', 'B19101A_012', 'B19101A_013', 'B19101A_014', 'B19101A_015', 'B19101A_016', 'B19101A_017',
# 'B19101B_002', 'B19101B_003', 'B19101B_004', 'B19101B_005', 'B19101B_006', 'B19101B_007', 'B19101B_008', 'B19101B_009', 'B19101B_010', 'B19101B_011', 'B19101B_012', 'B19101B_013', 'B19101B_014', 'B19101B_015', 'B19101B_016', 'B19101B_017',
# 'B19101C_002', 'B19101C_003', 'B19101C_004', 'B19101C_005', 'B19101C_006', 'B19101C_007', 'B19101C_008', 'B19101C_009', 'B19101C_010', 'B19101C_011', 'B19101C_012', 'B19101C_013', 'B19101C_014', 'B19101C_015', 'B19101C_016', 'B19101C_017',
# 'B19101D_002', 'B19101D_003', 'B19101D_004', 'B19101D_005', 'B19101D_006', 'B19101D_007', 'B19101D_008', 'B19101D_009', 'B19101D_010', 'B19101D_011', 'B19101D_012', 'B19101D_013', 'B19101D_014', 'B19101D_015', 'B19101D_016', 'B19101D_017',
# 'B19101E_002', 'B19101E_003', 'B19101E_004', 'B19101E_005', 'B19101E_006', 'B19101E_007', 'B19101E_008', 'B19101E_009', 'B19101E_010', 'B19101E_011', 'B19101E_012', 'B19101E_013', 'B19101E_014', 'B19101E_015', 'B19101E_016', 'B19101E_017',
# 'B19101F_002', 'B19101F_003', 'B19101F_004', 'B19101F_005', 'B19101F_006', 'B19101F_007', 'B19101F_008', 'B19101F_009', 'B19101F_010', 'B19101F_011', 'B19101F_012', 'B19101F_013', 'B19101F_014', 'B19101F_015', 'B19101F_016', 'B19101F_017',
# 'B19101G_002', 'B19101G_003', 'B19101G_004', 'B19101G_005', 'B19101G_006', 'B19101G_007', 'B19101G_008', 'B19101G_009', 'B19101G_010', 'B19101G_011', 'B19101G_012', 'B19101G_013', 'B19101G_014', 'B19101G_015', 'B19101G_016', 'B19101G_017',
# 'B19101H_002', 'B19101H_003', 'B19101H_004', 'B19101H_005', 'B19101H_006', 'B19101H_007', 'B19101H_008', 'B19101H_009', 'B19101H_010', 'B19101H_011', 'B19101H_012', 'B19101H_013', 'B19101H_014', 'B19101H_015', 'B19101H_016', 'B19101H_017')
