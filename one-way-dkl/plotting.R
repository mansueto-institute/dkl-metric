
plot_bin_bar_facets <- function(df, group_lab, cbsa){
  lvls <- df %>% 
    filter(group_label == group_lab) %>% 
    select(label) %>% 
    distinct() %>% 
    pull(label)
  
  df$label <- factor(df$label, levels = lvls)
  
  df %>%
    filter(group_label == group_lab, cbsa_fips == cbsa) %>%
    select(group_label, cbsa_fips, label, dkl_bin, year) %>%
    distinct() %>%
    ggplot(aes(x = dkl_bin, y = str_wrap(label, width = 40), fill = as.integer(label))) +
    geom_bar(stat = "identity") +
    geom_text(aes(label = round(dkl_bin, digits=2)), hjust = -0.1, size = 3) +
    scale_fill_viridis_c() +
    facet_wrap(~year, scales = "free_y") +
    labs(title = paste("DKL by", group_lab),
         subtitle = "For Chicago-Naperville-Elgin, IL-IN-WI") +
    theme_minimal() +
    theme(legend.position = "none",
          axis.title.y = element_blank())
}

plot_bin_bar_dodge <- function(df, group_lab, cbsa){
  df %>%
    filter(group_label == group_lab, cbsa_fips == cbsa) %>%
    select(group_label, cbsa_fips, label, dkl_bin, year) %>%
    distinct() %>%
    ggplot(aes(x = label, y = dkl_bin, fill = fct_rev(factor(year)))) +
    coord_flip() +
    geom_bar(stat = "identity", position = "dodge") +
    geom_text(aes(label = round(dkl_bin, digits = 2)), position = position_dodge(width = 0.9), hjust = -0.1, size = 3) +
    scale_fill_viridis_d() +  
    labs(title = "DKL by Income Buckets",
         fill = "Year") +
    theme_minimal() +
    theme(legend.position = "right",
          axis.title.y = element_blank())
}
