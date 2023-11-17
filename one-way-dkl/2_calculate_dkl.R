##################################################
## Calculates one-way DKL
##
## Nov 17 2023
##################################################

# install.packages("pacman")
pacman::p_load(tidyverse, arrow)

source("dkl.R")

options(scipen=9999)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
wd_dev <- getwd()

df_2015 <- read_parquet("data/clean_acs_tract_all_us_data_2015.parquet")
df_2020 <- read_parquet("data/clean_acs_tract_all_us_data_2020.parquet")

# need to find a way to remove "Estimate Total" from label column for 2015 
# since it contains an extra !!, maybe add a ":"?

# DKL
df20_dkl <- get_dkl(df_2020)
df15_dkl <- get_dkl(df_2015)

# explore data ------------------------------------------




