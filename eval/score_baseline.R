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
        "text^3.5"
        ),
      "query" = string))
}

# query_template and con must be set before
source("eval/eval.R")


raw <- list()
for (t in unique(tests$topic)) {
  x <- get_search(t, con) %>% 
    get_ids() %>% 
    mutate(final = es_score)
  raw[[as.character(t)]] <- x
}

map_df(raw, function(x) {
  y <- x %>% 
    slice(1:100) %>% 
    mutate(QTYPE = "QR",
           RANK = 1:nrow(x),
           RUNID = "osc_token")
  
  # check if query is topical or not
  topical <- inner_join(tests, y) %>% 
    filter(type == "topical")
  
  if (nrow(topical) < 1) {
    z <- y
  } else {
    z <- bind_rows(
      y,
      mutate(y, QTYPE = "QE"),
      mutate(y, QTYPE = "QD"),
      mutate(y, QTYPE = "QS")
    ) 
  }
  
  z %>% 
    select(TOPICID = topic,
           QTYPE,
           EPISODEID_OFFSET = id,
           RANK,
           SCORE = final,
           RUNID)
}) %>% 
  write_tsv("submission/osc_token.tsv", col_names = F)

# Score it ----------------------------------------------------------------

scores <- score_all(qrels, topics, con)

scores %>% crossbar_plot(title = "baseline")

scores %>% with(mean(ndcg))



