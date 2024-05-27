
get_dkl <- function(clean_acs){
  df <- clean_acs %>% 
    mutate(p_ni = tract_total / cbsa_total, # Prob of being in tract in MSA 
           p_ni_yj = tract_estimate / cbsa_estimate, # Prob of being in tract among people in bin 
           p_yj = cbsa_estimate / cbsa_total, # Prob of being in bin for everyone in MSA 
           p_yj_ni = tract_estimate / tract_total) %>%
    # replace all NaN porduced from 0/0 to 0
    mutate_at(vars(p_ni,p_ni_yj,p_yj,p_yj_ni), ~replace(., is.nan(.), 0)) %>%
    mutate(dkl_log_i = log2(p_yj_ni / p_yj), # share of income in tract relative to share of income in metro
           djl_log_j = log2(p_ni_yj / p_ni) # tract share of metro bin relative to share of tract in metro
    ) %>%
    # replace all NaN and -Inf produced from taking log(0) and v small numbers
    mutate_at(vars(dkl_log_i, djl_log_j), ~replace(., is.infinite(.), 0)) %>%
    mutate_at(vars(dkl_log_i, djl_log_j), ~replace(., is.nan(.), 0)) %>%
    mutate(dkl_tract_j = p_yj_ni * dkl_log_i, # DKL tract component
           dkl_bin_i = p_ni_yj * djl_log_j) %>% # DKL bin component
    # Sum DKL tract components
    group_by(variable_group, tract_fips) %>% 
    mutate(dkl_tract = sum(dkl_tract_j)) %>% 
    ungroup() %>% 
    # Sum DKL bin components
    group_by(variable_group, cbsa_fips, variable) %>% 
    mutate(dkl_bin = sum(dkl_bin_i )) %>% 
    ungroup() # Sum DKL bin components
  
  return(df)
}