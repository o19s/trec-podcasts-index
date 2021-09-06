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
tokens <- get_search(29, con) %>% 
  get_ids()

vector_rescore <- function(tokens) {
  vector_hits <-  glue::glue("embedding/cache/angles-{unique(tokens$topic)}.json") %>% 
    jsonlite::read_json()
  
  score <- data.frame(
    id = map_chr(vector_hits, ~ .$id) %>% paste0("spotify:episode:", ., ".0"),
    vector_score = map_dbl(vector_hits, ~ .$similarity)
  ) %>% 
    left_join(tokens, ., by = "id") %>% 
    replace_na(list(vector_score = 0)) %>% 
    mutate(score = es_score + vector_score) %>% 
    arrange(desc(score))
  # %>%
  # score_ids()
  # 
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


### Submissions ---

vector_subs <- list()
for (t in unique(tests$topic)) {

  vector_subs[[as.character(t)]] <- get_search(t, con) %>% 
    get_ids() %>% 
    vector_rescore() %>% 
    mutate(final = score)
}

map_df(vector_subs, function(x) {
  y <-  x %>% 
    slice(1:nrow(x)) %>% 
    mutate(QTYPE = "QR",
           RANK = 1:nrow(x),
           RUNID = "osc_tok_vec") %>% 
    group_by(id) %>% 
    slice(1) %>% 
    ungroup() 
  
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
  write_tsv("submission/osc_tok_vec.tsv", col_names = F)

es_scores %<>% bind_rows() %>% rename(ndcg_es = ndcg)
vector_scores %<>% bind_rows() %>% rename(ndcg_vec = ndcg)
  
dat <- inner_join(es_scores, vector_scores) %>% 
  inner_join(topics) %>% 
  select(-description) %>% 
  arrange(desc(ndcg_es)) %>% 
  mutate(topic = fct_inorder(as.character(topic)))


avg_lines <- dat %>%
  group_by(type) %>% 
  summarise(avg_vec = mean(ndcg_vec),
            avg_es = mean(ndcg_es)) %>% 
  gather("key", "value", -type)
  
p_post <- ggplot(dat, aes(y = topic)) +
  geom_point(aes(x = ndcg_es, color = "ES base")) +
  geom_point(aes(x = ndcg_vec, color = "Sbert rescore")) +
  geom_vline(data = avg_lines, aes(xintercept = value, color = key))+
  facet_grid(type ~ ., scales = "free_y", space = "free_y")

mean(dat$ndcg_es)
mean(dat$ndcg_vec)


