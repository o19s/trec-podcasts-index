source("eval/eval.R") # brings in some Data and Functions

library(elastic)
library(tidyverse)

con <- connect()

# res <- topics$query[topic_num] %>% 
#   Search(con, "podcasts_summary", q = .)


# Some more functions -----------------------------------------------------
# TODO: move elsewhere

get_query <- function(topic) {
  topics[topics$topic == topic, 'query']
}

get_query(2)

get_search <- function(topic, ...) {
  
  query <- get_query(topic)
  
  query_req <- list(
    "size" = 30,
    "_source" = list(
      "episode_filename_prefix",
      "episode_name",
      "episode_description"
    ),
    "query" = list(
      "combined_fields" = list(
        "fields" = list("episode_description", "episode_name"),
        "query" = query
      )
    )
  )
  
  Search(con, "podcasts_summary", body = query_req)
}
  
res <- get_search(2)
res

get_ids <- function(res, topic) {
  if (res[['hits']][['total']] == 0) {
    stop("No results from Elastic!!!")
  } else {
    res[['hits']][['hits']] %>% 
      map_chr(~ .[['_source']][['episode_filename_prefix']]) %>% 
      paste0("spotify:episode:", .) %>% 
      data.frame(topic = topic, id = ., result = T)
  }
}

ids <- get_ids(res, 2)

score_ids <- function(ids, topic) {
  
  topic_qrels <- qrels %>% 
    filter(topic %in% unique(ids$topic)) %>% 
    mutate(id = gsub("_.*", "", id)) %>% 
    group_by(topic, id) %>% 
    summarise(grade = max(grade), .groups = 'drop') %>% 
    arrange(desc(grade))
  
  ids %>% 
    left_join(topic_qrels, by = c("topic", "id")) %>% 
    pull(grade) %>% 
    replace_na(0) %>% 
    c(topic_qrels$grade) %>% 
    ndcg()
}


# Wrangle sandbox ---------------------------------------------------------

# exploring scoring and our baseline ranking
topic_num <- 8
get_query(topic_num)
ids <- get_search(topic_num) %>% 
  get_ids(topic_num)

ids %>% score_ids(topic_num)

scores <- list()
for (t in unique(qrels$topic)) {
  print(t)
  scores[[t]] <- get_search(t) %>% 
    get_ids(t) %>% 
    score_ids()
}


# looking at qrel data at large
qrels[qrels$topic == topic_num,] %>% 
  mutate(id = gsub(".*\\:", "", id)) %>% arrange(desc(grade)) %>% head()
  separate(id, c("episode", "sec"), sep = "_") %>% 
  remove_rownames() %>% 
  group_by(episode) %>% 
  summarise(avg_grade = mean(grade),
            n = n()) %>% 
  arrange(desc(avg_grade)) %>% 
  View()
