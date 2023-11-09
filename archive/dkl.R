
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

# Setup -------------------------------------------------------------------

# 1. Obtain Census API Key here: https://api.census.gov/data/key_signup.html
# 2. Run census_api_key function to add API_KEY to .Renviron
# census_api_key('API_KEY', install = TRUE) 
# 3. Restart RStudio

# Another option is to simply run:
# Sys.getenv("API_KEY") 

# Read the .Renviron file (only necessary fi you ran census_api_key()
readRenviron("~/.Renviron")

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

# Investigate Census Variables
acs5_vars <- load_variables(year = 2019, dataset = c('acs5'), cache = FALSE) 
# Separate concept column so its easier to sort through
acs5_vars <- acs5_vars %>% separate(col = 'concept',  
                                    into = c('concept_main','concept_part'),
                                    sep = c(' BY '),
                                    remove = FALSE,
                                    extra = "merge") %>%
  mutate(concept_part = case_when(is.na(concept_part) ~ 'TOTAL',
                                  TRUE ~ as.character(concept_part)))

# Create HTML Search Window to find variables
explore_acs_vars()

# acs5_vars_selected <- c('B23025_004','B23025_005','B23025_006','B23025_007',
#                         'B06001_002','B06001_003','B06001_004','B06001_005','B06001_006','B06001_007','B06001_008','B06001_009','B06001_010','B06001_011','B06001_012',
#                         'B19001_002','B19001_003','B19001_004','B19001_005','B19001_006','B19001_007','B19001_008','B19001_009','B19001_010','B19001_011','B19001_012','B19001_013','B19001_014','B19001_015','B19001_016','B19001_017',
#                         'B19001A_002','B19001A_003','B19001A_004','B19001A_005','B19001A_006','B19001A_007','B19001A_008','B19001A_009','B19001A_010','B19001A_011','B19001A_012','B19001A_013','B19001A_014','B19001A_015','B19001A_016','B19001A_017',
#                         'B19001B_002','B19001B_003','B19001B_004','B19001B_005','B19001B_006','B19001B_007','B19001B_008','B19001B_009','B19001B_010','B19001B_011','B19001B_012','B19001B_013','B19001B_014','B19001B_015','B19001B_016','B19001B_017',
#                         'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
#                         'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
#                         'B19001D_002','B19001D_003','B19001D_004','B19001D_005','B19001D_006','B19001D_007','B19001D_008','B19001D_009','B19001D_010','B19001D_011','B19001D_012','B19001D_013','B19001D_014','B19001D_015','B19001D_016','B19001D_017',
#                         'B19001E_002','B19001E_003','B19001E_004','B19001E_005','B19001E_006','B19001E_007','B19001E_008','B19001E_009','B19001E_010','B19001E_011','B19001E_012','B19001E_013','B19001E_014','B19001E_015','B19001E_016','B19001E_017',
#                         'B19001F_002','B19001F_003','B19001F_004','B19001F_005','B19001F_006','B19001F_007','B19001F_008','B19001F_009','B19001F_010','B19001F_011','B19001F_012','B19001F_013','B19001F_014','B19001F_015','B19001F_016','B19001F_017',
#                         'B19001G_002','B19001G_003','B19001G_004','B19001G_005','B19001G_006','B19001G_007','B19001G_008','B19001G_009','B19001G_010','B19001G_011','B19001G_012','B19001G_013','B19001G_014','B19001G_015','B19001G_016','B19001G_017',
#                         'B19001H_002','B19001H_003','B19001H_004','B19001H_005','B19001H_006','B19001H_007','B19001H_008','B19001H_009','B19001H_010','B19001H_011','B19001H_012','B19001H_013','B19001H_014','B19001H_015','B19001H_016','B19001H_017',
#                         'B19001I_002','B19001I_003','B19001I_004','B19001I_005','B19001I_006','B19001I_007','B19001I_008','B19001I_009','B19001I_010','B19001I_011','B19001I_012','B19001I_013','B19001I_014','B19001I_015','B19001I_016','B19001I_017',  
#                         'B08126_002','B08126_003','B08126_004','B08126_005','B08126_006','B08126_007','B08126_008','B08126_009','B08126_010','B08126_011','B08126_012','B08126_013','B08126_014','B08126_015',        
#                         'B08124_002','B08124_003','B08124_004','B08124_005','B08124_006','B08124_007',
#                         'B15003_002','B15003_003','B15003_004','B15003_005','B15003_006','B15003_007','B15003_008','B15003_009','B15003_010','B15003_011','B15003_012','B15003_013','B15003_014','B15003_015','B15003_016',
#                         'B15003_017','B15003_018','B15003_019','B15003_020','B15003_021','B15003_022','B15003_023','B15003_024','B15003_025',
#                         'B02001_002','B02001_003','B02001_004','B02001_005','B02001_006','B02001_007','B02001_008',
#                         'B03001_002','B03001_003')

acs5_vars_selected <- c('B11001A_002', 'B11001B_002', 'B11001C_002', 'B11001D_002', 'B11001E_002', 'B11001F_002', 'B11001G_002', 'B11001H_002',
                        'B19101_002', 'B19101_003', 'B19101_004', 'B19101_005', 'B19101_006', 'B19101_007', 'B19101_008', 'B19101_009', 'B19101_010', 'B19101_011', 'B19101_012', 'B19101_013', 'B19101_014', 'B19101_015', 'B19101_016', 'B19101_017',
                        'B19101A_002', 'B19101A_003', 'B19101A_004', 'B19101A_005', 'B19101A_006', 'B19101A_007', 'B19101A_008', 'B19101A_009', 'B19101A_010', 'B19101A_011', 'B19101A_012', 'B19101A_013', 'B19101A_014', 'B19101A_015', 'B19101A_016', 'B19101A_017',
                        'B19101B_002', 'B19101B_003', 'B19101B_004', 'B19101B_005', 'B19101B_006', 'B19101B_007', 'B19101B_008', 'B19101B_009', 'B19101B_010', 'B19101B_011', 'B19101B_012', 'B19101B_013', 'B19101B_014', 'B19101B_015', 'B19101B_016', 'B19101B_017',
                        'B19101C_002', 'B19101C_003', 'B19101C_004', 'B19101C_005', 'B19101C_006', 'B19101C_007', 'B19101C_008', 'B19101C_009', 'B19101C_010', 'B19101C_011', 'B19101C_012', 'B19101C_013', 'B19101C_014', 'B19101C_015', 'B19101C_016', 'B19101C_017',
                        'B19101D_002', 'B19101D_003', 'B19101D_004', 'B19101D_005', 'B19101D_006', 'B19101D_007', 'B19101D_008', 'B19101D_009', 'B19101D_010', 'B19101D_011', 'B19101D_012', 'B19101D_013', 'B19101D_014', 'B19101D_015', 'B19101D_016', 'B19101D_017',
                        'B19101E_002', 'B19101E_003', 'B19101E_004', 'B19101E_005', 'B19101E_006', 'B19101E_007', 'B19101E_008', 'B19101E_009', 'B19101E_010', 'B19101E_011', 'B19101E_012', 'B19101E_013', 'B19101E_014', 'B19101E_015', 'B19101E_016', 'B19101E_017',
                        'B19101F_002', 'B19101F_003', 'B19101F_004', 'B19101F_005', 'B19101F_006', 'B19101F_007', 'B19101F_008', 'B19101F_009', 'B19101F_010', 'B19101F_011', 'B19101F_012', 'B19101F_013', 'B19101F_014', 'B19101F_015', 'B19101F_016', 'B19101F_017',
                        'B19101G_002', 'B19101G_003', 'B19101G_004', 'B19101G_005', 'B19101G_006', 'B19101G_007', 'B19101G_008', 'B19101G_009', 'B19101G_010', 'B19101G_011', 'B19101G_012', 'B19101G_013', 'B19101G_014', 'B19101G_015', 'B19101G_016', 'B19101G_017',
                        'B19101H_002', 'B19101H_003', 'B19101H_004', 'B19101H_005', 'B19101H_006', 'B19101H_007', 'B19101H_008', 'B19101H_009', 'B19101H_010', 'B19101H_011', 'B19101H_012', 'B19101H_013', 'B19101H_014', 'B19101H_015', 'B19101H_016', 'B19101H_017')
                        
# B19101I	Hispanic or Latino
# B19101H	White alone, not Latino
# B19101A	White alone

# acs5_vars_selected <- c('B19001_002','B19001_003','B19001_004','B19001_005','B19001_006','B19001_007','B19001_008','B19001_009','B19001_010','B19001_011','B19001_012','B19001_013','B19001_014','B19001_015','B19001_016','B19001_017',
#                         'B02001_002','B02001_003','B02001_004','B02001_005','B02001_006','B02001_007','B02001_008')

# 'B06010_001','B06010_003','B25121_001','B08126_001','B08124_001','B15003_001','B02001_001','B03001_001'

# Download state codes via tidycensus' "fips_codes" data set
state_xwalk <- as.data.frame(fips_codes) %>%
  rename(state_fips = state_code,
         state_codes = state,
         county_name = county) %>%
  mutate(county_fips = paste0(state_fips,county_code))
# Make lists for FIPS and codes
state_fips <- unique(state_xwalk$state_fips)[1:51]
state_codes <- unique(state_xwalk$state_codes)[1:51]

# Subset to states of interest (use state_codes list to get all states)
state_list <- c('IL') #,'WI','IN'

# acs5_vars_selected <- c('B23025_004','B23025_005')

# Use purrr function map_df to run a get_acs call that loops over all states
acs_tract_all_us_data <- map_dfr(.x = state_list, .f = function(x) {
  get_acs(year = 2019, geography = "tract", survey = 'acs5', 
          variables = acs5_vars_selected, 
          state = x)
})

#explore_acs_vars()

df <- acs_tract_all_us_data %>%
  rename_all(list(tolower)) %>%
  left_join(., acs5_vars %>% select(name, label), by = c('variable' = 'name')) %>%
  mutate(label = gsub("Estimate!!Total:", "", label), 
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
  mutate(variable_supergroup = gsub("[^0-9]$", "", variable_group)) %>%
  mutate(label = case_when(variable_group %in% c('B19001A','B19101A') ~ paste0('White alone',' - ',label),
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
                                 variable_group == "B03001" ~ 'Hispanic or Latino',
                                 variable_group == "B08124" ~ 'Occupation',
                                 variable_group == "B08126" ~ 'Industry',
                                 variable_group == "B15003" ~ 'Education attainment',
                                 variable_group == 'B23025' ~ 'Employment status',
                                 variable_group == 'B06001' ~ 'Age',
                                 variable_group == 'B19001' ~ 'Household income', 
                                 variable_group %in% c('B19101A','B19101B','B19101C','B19101D','B19101E','B19101F','B19101G','B19101H','B19101I') ~ 'Race and Household income', #
                                 variable_group %in% c('B19001A','B19001B','B19001C','B19001D','B19001E','B19001F','B19001G','B19001H','B19001I') ~ 'Race and Household income'), #
                                 # variable_group == 'B19001A' ~ 'Household income - White alone',
                                 # variable_group == 'B19001B' ~ 'Household income - Black or African American alone',
                                 # variable_group == 'B19001C' ~ 'Household income - Native American alone',
                                 # variable_group == 'B19001D' ~ 'Household income - Asian alone',
                                 # variable_group == 'B19001E' ~ 'Household income - Pacific Islander alone',
                                 # variable_group == 'B19001F' ~ 'Household income - Some other race alone',
                                 # variable_group == 'B19001G' ~ 'Household income - Two or more races',
                                 # variable_group == 'B19001H' ~ 'Household income - White alone, not Latino',
                                 # variable_group == 'B19001I' ~ 'Household income - Hispanic or Latino'),
         county_fips = str_sub(geoid,1,5)) %>%
  left_join(., state_xwalk, by = c('county_fips'='county_fips')) %>%
  left_join(.,cbsa_xwalk, by = c('county_fips'='county_fips')) %>%
  mutate(latino_adjustment = case_when(variable_group == 'B19101H' ~ -1*estimate,
                                       variable_group == 'B19101A' ~ estimate,
                                       TRUE ~ as.numeric(0)),
         white_latino_group = case_when(variable_group == 'B19101H' ~ 1,
                                       variable_group == 'B19101A' ~ 1,
                                       TRUE ~ as.numeric(0))) %>% 
  group_by(geoid, white_latino_group, variable_item) %>%
  mutate(latino_estimate = sum(latino_adjustment)) %>%
  ungroup() %>%
  mutate(estimate = case_when(variable_group == 'B19101A' ~ latino_estimate,
                              TRUE ~ as.numeric(estimate)),
         label = case_when(variable_group %in% c('B19001A','B19101A') ~ gsub('White alone - ','Latino alone - ',label),
                           TRUE ~ as.character(label))) 

# p_ni = tract pop / msa population
# p_yj_ni = number of people of income in bin in tract / number of people in tract
# p_ni_yj = number of people of income in bin in tract / number of people across all msa in income bin
# p_yj = check to make sure everything sums to 1 
# for each neighborhood sum( p_yj_ni * log (p_yj_ni / p_yj ) )
# for each income bin sum( p_ni_yj * log (p_ni_yj / p_ni ) )

df2 <- df %>%
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
                           "Milwaukee-Waukesha, WI")) %>% 
  mutate(p_ni = tract_total / cbsa_total, # Prob of being in tract in MSA 
         p_ni_yj = tract_estimate / cbsa_estimate, # Prob of being in tract among people in bin 
         p_yj = cbsa_estimate / cbsa_total, # Prob of being in bin for everyone in MSA 
         p_yj_ni = tract_estimate / tract_total) %>% # Prob of being in bin among people in tract 
  mutate_at(vars(p_ni,p_ni_yj,p_yj,p_yj_ni), ~replace(., is.nan(.), 0)) %>%
  mutate(dkl_log_i = log(p_yj_ni / p_yj), # share of income in tract relative to share of income in metro
         djl_log_j = log(p_ni_yj / p_ni) # tract share of metro bin relative to share of tract in metro
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
  ungroup() # Sum DKL bin components
         
#add single dkl
df3 <- df %>%
  filter(group_label %in% c('Race and Household income','Household income', 'Race')) %>% 
  separate(col = 'label',  
           into = c('label_race','label_income'),
           sep = c(' - '),
           remove = FALSE,
           extra = "merge") %>% 
  select(tract_fips, county_fips, county_name, cbsa_fips, cbsa_title, area_type, central_outlying_county, state_codes, state_fips, state_name, variable, variable_group, variable_item, group_label, label, label_race, label_income, tract_estimate, moe) %>%
  group_by(cbsa_fips, group_label, label_race) %>%
  mutate(cbsa_estimate_race = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, group_label, label_income) %>%
  mutate(cbsa_estimate_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, group_label, label) %>%
  mutate(cbsa_estimate_race_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, group_label) %>%
  mutate(cbsa_total = sum(tract_estimate)) %>% ungroup() %>%
  group_by(tract_fips, group_label, label_race) %>%
  mutate(tract_estimate_race = sum(tract_estimate)) %>%  ungroup() %>%
  group_by(tract_fips, group_label, label_income) %>%
  mutate(tract_estimate_income = sum(tract_estimate)) %>% ungroup() %>%
  group_by(tract_fips, group_label, label) %>%
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
  mutate(dkl_jz_log = log((p_yj_ni/p_yj) * (p_zk_ni/p_zk) * ((p_yj*p_zk) / p_yjzk ) * (p_yjzk_ni / (p_yj_ni * p_zk_ni ))))  %>%
  mutate_at(vars(dkl_jz_log), ~replace(., is.infinite(.), 0)) %>%
  mutate_at(vars(dkl_jz_log), ~replace(., is.nan(.), 0)) %>%
  group_by(tract_fips, group_label) %>% 
  mutate(dkl_jz = sum(p_yjzk_ni * dkl_jz_log)) %>% ungroup()




#explore_acs_vars()
#B19101A
# a <- df2  %>% filter(group_label %in% c('Race','Household income','Race and Household income',
#                                         'Age'),
#                      tract_fips == '17031010201') %>% 
#   select(tract_fips, group_label, variable, label, tract_estimate, tract_pct) 
#   write_csv(a, '/Users/nm/Desktop/race_inc.csv')

a <- df2  %>% filter(group_label %in% c('Race','Household income')) %>% 
  select(tract_fips, group_label, dkl_tract) %>% distinct() %>%
  pivot_wider(id_cols = c(tract_fips),
              names_from = c(group_label), 
              values_from = c(dkl_tract)) 

a <- df2  %>% filter(group_label %in% c('Race','Household income')) %>% 
  select(tract_fips, group_label, dkl_tract) %>% distinct() %>%
  pivot_wider(id_cols = c(tract_fips),
              names_from = c(group_label), 
              values_from = c(dkl_tract)) 
b <- df3 %>% 
  filter(group_label == 'Race and Household income') %>%
  select(tract_fips, dkl_jz) %>% distinct()

c <- geom_tract %>% left_join(., b, by = c('GEOID'='tract_fips')) %>%
  left_join(., a, by = c('GEOID'='tract_fips')) %>%
  mutate(residual = dkl_jz - Race - `Household income`)


# Visualizations of Tracts
(p1 <- ggplot(geom_tract %>% left_join(., df2, by = c('GEOID'='tract_fips')) %>% filter(group_label == 'Race'), 
              aes(fill = dkl_tract , color =  dkl_tract)) +
    geom_sf() + scale_fill_viridis() + scale_color_viridis() +
    labs(subtitle = 'Race') +
    theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(p2 <- ggplot(geom_tract %>% left_join(., df2, by = c('GEOID'='tract_fips')) %>% filter(group_label == 'Household income'), 
              aes(fill = dkl_tract , color =  dkl_tract)) +
    geom_sf() + scale_fill_viridis() + scale_color_viridis() +
    labs(subtitle = 'Household income') +
    theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(p3 <- ggplot(geom_tract %>% left_join(., df3 %>% 
                                  filter(group_label == 'Race and Household income') %>%
                                  select(tract_fips, dkl_jz) %>% distinct()
                                , by = c('GEOID'='tract_fips')), 
       aes(fill = dkl_jz , color =  dkl_jz)) +
  geom_sf() + scale_fill_viridis() + scale_color_viridis() +
  labs(subtitle = 'Race and household income') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))
         
(p4 <- ggplot(c, aes(fill = residual , color =  residual)) +
#(p4 <- ggplot(c, aes(fill = residual ), color = 'white', size = .05) +
  geom_sf() + 
    #scale_fill_gradientn(colors=c("red","white","blue"),breaks=c(-.03,-.015,-.01,.2,.8,1.2)) +
    #scale_fill_gradient2(low = "red", high = "blue") + #, mid = "#ffffff", midpoint = 0) + 
    #scale_fill_gradient2(low = "#F77552", high = "#0194D3", mid = "#ffffff", midpoint = 0) +
    scale_fill_viridis() + scale_color_viridis() +
  labs(subtitle = 'Residual') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

#df3 %>% filter(group_label == 'Race and Household income') %>% select(label_race) %>% pull() %>% unique()
# df3 %>% filter(group_label == 'Race and Household income') %>% select(label_income) %>% pull() %>% unique()
# a <- df3 %>% filter(variable %in% c('B19001A_002', 'B19001H_002','B19001I_002'),
#                     tract_fips == '17031010100')
(p3 + p1 + p2 + p4) + 
  plot_annotation(subtitle = 'Kullback–Leibler divergence of\ntracts to metro probability distributions',
                  theme = theme(plot.subtitle = element_text(size = 10, hjust = .5))) 

ggplot(geom_tract %>% left_join(., df2 %>% 
                                  filter(group_label == 'Race') %>%
                                  select(tract_fips, tract_pct) %>% distinct(), by = c('GEOID'='tract_fips')), 
       aes(fill = tract_pct , color =  tract_pct)) +
  geom_sf() + scale_fill_viridis() + scale_color_viridis() +
  labs(subtitle = 'Asian share') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank())


  mutate(p_yj = cbsa_estimate_r / cbsa_total,
         p_zk = cbsa_estimate_i / cbsa_total,
         p_yjzk = cbsa_estimate_ri / cbsa_total) %>%
  mutate(p_yj_ni = tract_estimate_r / tract_total,
         p_zk_ni = tract_estimate_i / tract_total,
         p_yjzk_ni = tract_estimate_ri / tract_total) %>%
  mutate(dkl_jz = sum(p_yjzk_ni * log((p_yj_ni/p_yj) * (p_zk_ni/p_zk) * ((p_yj*p_zk) / p_yjzk ) * (p_yjzk_ni / (p_yj_ni * p_zk_ni )))) ) 
  
  

  
  

    

  
  
  

# Viz ---------------------------------------------------------------------


geom_tract <- get_acs(year = 2019, geography = "tract", survey = 'acs5', variables = 'B02001_001', state = '17', county = '031', geometry = TRUE) %>%
  select(GEOID) %>% st_transform(crs = st_crs(4326)) 

community_areas <- sf::st_read('https://data.cityofchicago.org/api/geospatial/cauq-8yn6?method=export&format=GeoJSON') %>% 
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf() %>% 
  select(community)

geom_tract <- geom_tract %>%
  st_join(., community_areas, left= TRUE, largest = TRUE) %>%
  filter(!is.na(community))





p3 <- ggplot(geom_tract %>% left_join(., df2, by = c('GEOID'='tract_fips')) %>% filter(group_label == 'Education attainment'), 
       aes(fill = dkl_tract , color =  dkl_tract)) +
  geom_sf() + scale_fill_viridis() + scale_color_viridis() +
  labs(subtitle =  'Education attainment') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank())

ggplot(geom_tract %>% left_join(., df2, by = c('GEOID'='tract_fips')) %>% filter(group_label == 'Age'), 
       aes(fill = dkl_tract , color =  dkl_tract)) +
  geom_sf() + scale_fill_viridis() + scale_color_viridis() +
  labs(subtitle =  '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank())

ggplot(geom_tract %>% left_join(., df2, by = c('GEOID'='tract_fips')) %>% filter(group_label == 'Occupation'), 
       aes(fill = dkl_tract , color =  dkl_tract)) +
  geom_sf() + scale_fill_viridis() + scale_color_viridis() +
  labs(subtitle =  '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank())

p4 <- p1 + p2 +p3
p4

# Bar charts
df3 <- df2 
lvls <- df2 %>% filter(group_label == 'Race') %>% select(label) %>% distinct() %>% pull(label)
df3$label <- factor(df2$label, levels = lvls)
ggplot(df3 %>% filter(group_label == 'Race', cbsa_fips == '16980') %>% select(group_label, cbsa_fips, label, dkl_bin) %>% distinct()) +
  geom_bar(aes(x= dkl_bin, y = label), stat="identity") 

lvls <- df2 %>% filter(group_label == 'Household income') %>% select(label) %>% distinct() %>% pull(label)
df3$label <- factor(df2$label, levels = lvls)
ggplot(df3 %>% filter(group_label == 'Household income', cbsa_fips == '16980') %>% select(group_label, cbsa_fips, label, dkl_bin) %>% distinct()) +
  geom_bar(aes(x= dkl_bin, y = label, fill = label), stat="identity") 

lvls <- df2 %>% filter(group_label ==  'Education attainment') %>% select(label) %>% distinct() %>% pull(label)
df3$label <- factor(df2$label, levels = lvls)
ggplot(df3 %>% filter(group_label == 'Education attainment', cbsa_fips == '16980') %>% select(group_label, cbsa_fips, label, dkl_bin) %>% distinct()) +
  geom_bar(aes(x= dkl_bin, y = label), stat="identity") 


write_csv(df, '/Users/nm/Desktop/dkl_input_data.csv')

write_csv(df %>% filter(tract_fips == '17031010100'), '/Users/nm/Desktop/dkl_test.csv')

unique(df$group_label)



