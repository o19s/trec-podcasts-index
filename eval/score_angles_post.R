#' Baseline strategy / template
#' 
#' A ES connection, `con` and a function `query_template()` must be defined in each score_X.R script if
#' `get_search()` is being used. `rescore_template` will need to be added in a
#' similar fashion
#' 
#'
library(magrittr)
con <- elastic::connect()

query_template <- function(string) {
  list(
    "combined_fields" = list(
      "fields" = list(
        "episode_description",
        "episode_name",
        "text^3.5"),
      "query" = string))
}

# query_template and con must be set before
source("eval/eval.R")

# another way home for ID based rescore-ing
tokens <- get_search(24, con) %>% 
  get_ids()


vector_rescore <- function(tokens) {
  vector_hits <-  glue::glue("embedding/cache/angles-{unique(tokens$topic)}.json") %>% 
    jsonlite::read_json()
  
  score <- data.frame(
    id = map_chr(vector_hits, ~ .$id) %>% paste0("spotify:episode:", ., ".0"),
    vector_score = map_dbl(vector_hits, ~ .$similarity)
  ) %>% 
    left_join(tokens, .) %>% 
    replace_na(list(vector_score = 0)) %>% 
    mutate(score = es_score + vector_score) %>% 
    arrange(desc(score)) %>% 
    score_ids()
  
  return(score)
}

tokens %>% score_ids()
tokens %>% vector_rescore()

es_scores <- list()
vector_scores <- list()
for (t in unique(qrels$topic)) {
  es_scores[[t]] <- get_search(t, con) %>% 
    get_ids() %>%
    score_ids() %>% 
    data.frame(topic = t, ndcg = .)
  
  vector_scores[[t]] <- get_search(t, con) %>% 
    get_ids() %>%
    vector_rescore() %>% 
    data.frame(topic = t, ndcg = .)
  
}


es_scores %<>% bind_rows() %>% rename(ndcg_es = ndcg)
vector_scores %<>% bind_rows() %>% rename(ndcg_vec = ndcg)
  
inner_join(es_scores, vector_scores)

# mutate(ndcg = ndcg / max(ndcg)) %>% 
  inner_join(topics, by = "topic") %>% 
  select(-description)


token_hits %>% 
  mutate(doc_score = doc_score / max(doc_score))


# Score it ----------------------------------------------------------------

scores <- score_all(qrels, topics, con)

scores %>% crossbar_plot()

scores %>% with(mean(score))

