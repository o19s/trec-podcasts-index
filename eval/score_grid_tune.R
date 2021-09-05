#' Baseline strategy / template
#' 
#' A ES connection, `con` and a function `query_template()` must be defined in each score_X.R script if
#' `get_search()` is being used. `rescore_template` will need to be added in a
#' similar fashion
#' 
#' This strategy aims to improve on baseline by customizing query paramaters
library(tidyverse)
con <- elastic::connect()

param_ranges <- list(
  "field_values" = c("text", "episode_name", "show_name"),
  "boost_values" = c(1,2,3,4),
  "mms" = c("50%")
)

param_setter <- function(param_ranges) {
  
  for (f in param_ranges[['field_values']]) {
    param_ranges[[paste0(f, "_boosted")]] <- paste0(f, "^", param_ranges[['boost_values']])
  }
  
  fields_units <- param_ranges[grepl("_boosted", names(param_ranges))]
  
  fields <- expand.grid(fields_units, stringsAsFactors = F) %>% 
    as_tibble() %>% 
    rowwise() %>%
    mutate(value = list(list(text_boosted,episode_name_boosted, show_name_boosted))) %>% 
    pull(value)
  # 
  # map(fields, function(x) {
  #   return(list(x[c(T,T,F)],
  #               x[c(T,F,F)],
  #               x[c(F,T,F)],
  #               x[c(T,F,T)],
  #               x[c(F,T,F)]
  #               )]))}
  
  
  fields <- set_names(fields, map(fields, ~ unlist(.) %>% paste(collapse = "-")))
  
  param_templates <- list()
  mms <- set_names(param_ranges[['mms']])
  for (f in names(fields)) {
    for (m in names(mms)) {
      param_templates[[paste0(f, "-", m)]] <-  list(
        "combined_fields" = list(
          "fields" = fields[[f]], 
          "minimum_should_match" = mms[[m]])
      )}}
  
  return(param_templates)
}


score_catcher <- list()
params <- param_setter(param_ranges)

for (li_test in names(params)) {
  query_template <- function(string, li = params[[li_test]]) {
    li[['combined_fields']][['query']] = string
    return(li)
  }
  # query_template and con must be set before
  source("eval/eval.R")
  # 
  # get_search(topics$topic[1], con) %>%
  #   get_ids() %>%
  #   score_ids()

  # scores <- list()
  # for (t in unique(qrels$topic)) {
  #   scores[[t]] <- get_search(t, con) %>% 
  #     get_ids() %>% 
  #     score_ids() %>% 
  #     data.frame(topic = t, ndcg = .)
  # }
  # 
  
  score_catcher[[li_test]] <- score_all(qrels, topics, con) %>% 
    score_summary()
}


bind_rows(score_catcher, .id = "tune") %>% 
  gather(key = "type", value = "value", overall:topical) %>% 
  arrange(value) %>% 
  mutate(tune = fct_inorder(tune)) %>% 
  ggplot(aes(value, tune, color = type, size = type == "overall")) +
  geom_point(alpha = .5)


scores %>% crossbar_plot(title = "known item2")

scores %>% with(mean(ndcg))

