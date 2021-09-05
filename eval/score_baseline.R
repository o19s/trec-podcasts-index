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
        "episode_name",
        "show_name",
        "text^3"
        ),
      "query" = string))
}

# query_template and con must be set before
source("eval/eval.R")


# Score it ----------------------------------------------------------------

scores <- score_all(qrels, topics, con)

scores %>% crossbar_plot(title = "baseline")

scores %>% with(mean(ndcg))

