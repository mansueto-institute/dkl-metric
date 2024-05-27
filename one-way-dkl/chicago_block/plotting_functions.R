

get_var_df <- function(map_dkl_df, group_lab) {
  df <- map_dkl_df %>% 
    filter(group_label == group_lab) %>%
    select(GEOID, group_label, dkl_block) %>%
    distinct() 
  return(df)
}


# ---- for bars ----

plot_bin_bar_dodge <- function(df, group_lab, cbsa){
  
  lvls <- df %>% 
    filter(group_label == group_lab) %>% 
    select(label) %>% 
    distinct() %>% 
    pull(label)
  
  df %>%
    filter(group_label == group_lab, cbsa_fips == cbsa) %>%
    select(group_label, cbsa_fips, label, dkl_bin, year) %>%
    distinct() %>%
    mutate(label = factor(label, levels = lvls, ordered = TRUE)) %>% # ORDER
    ggplot(aes(x = label, y = dkl_bin, fill = fct_rev(factor(year)))) +
    coord_flip() +
    geom_bar(stat = "identity", position = "dodge") +
    geom_text(aes(label = round(dkl_bin, digits = 2)), position = position_dodge(width = 0.9), hjust = -0.1, size = 3) +
    scale_fill_manual(name = '', values = c("#7A2282", '#FEB078')) +
    labs(title = paste("DKL by", group_lab),
         subtitle = "For Chicago-Naperville-Elgin, IL-IN-WI",
         fill = "Year") +
    theme_minimal() +
    theme(legend.position = "right",
          axis.title.y = element_blank(),
          axis.text.y = element_text(hjust = 0),  # Adjust horizontal alignment of y-axis labels
          axis.text.x = element_text(angle = 45, hjust = 1)) +  # Rotate x-axis labels
    scale_x_discrete(labels = function(x) str_wrap(x, width = 30))  # Adjust width as needed
}



# ---- for maps ----

community_data <- data.frame(
  community = c("Downtown", "Hyde Park", "Chatham", "Riverdale", "Little Village", "Humboldt Park", "Lincoln Park", "Albany Park"),
  lon = c(-87.623177, -87.5917, -87.6146, -87.6149, -87.7050, -87.7213, -87.6488, -87.7280),
  lat = c(41.881832, 41.7948, 41.7401, 41.6476, 41.8445, 41.8991, 41.9255,41.9683)
)

map_dkl <- function(var_dkl_df, group_lab, year, max_range) {
  fig <- var_dkl_df %>%
    ggplot() +
    geom_sf(aes(fill = dkl_block), size = 0.001) +
    scale_fill_viridis_c(option = "magma", direction = -1, limits = c(0, max_range)) +
    labs(title = paste('DKL for', group_lab, year)) +
    geom_text(data = community_data, aes(x = lon, y = lat, label = community),
              color = "black", size = 2, hjust = 0, vjust = 0) +
    geom_text(data = community_data, aes(x = lon, y = lat, label = community),
              color = "white", size = 2, hjust = -0.01, vjust = -0.1) +
    theme_minimal() + 
    theme(legend.title = element_blank(), 
          legend.key.width = unit(0.5, "cm"),
          legend.key.height = unit(0.5, "cm"),
          legend.text = element_text(size = 7),
          axis.text = element_blank(),
          axis.title = element_blank())
  return(fig)
}
 
# map_most_freq_cat <- function(var_dkl_df, group_lab) {
#   df <- var_dkl_df %>%
#     group_by(GEOID) %>%
#     top_n(1, wt = percent_total) %>%
#     ungroup()
#   
#   mp <- df %>%
#     ggplot() +
#     geom_sf()
# 
#   return(mp)
# }
