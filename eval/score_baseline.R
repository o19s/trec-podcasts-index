#' Baseline strategy / template
#' 
#' A ES connection, `con` and a function `query_template()` must be defined in each score_X.R script if
#' `get_search()` is being used. `rescore_template` will need to be added in a
#' similar fashion
#' 
#'

con <- elastic::connect()

query_template <- function(string) {
  list(
    "combined_fields" = list(
      "fields" = list(
        "episode_description",
        "episode_name",
        "text^3.5"),
      "query" = string,
      "minimum_should_match" = "100%"))
}

# query_template and con must be set before
source("eval/eval.R")

# another way home for ID based rescore-ing
get_search(11, con) %>% 
  get_ids()


# Score it ----------------------------------------------------------------

scores <- score_all(qrels, topics, con)

scores %>% crossbar_plot()

scores %>% with(mean(score))

