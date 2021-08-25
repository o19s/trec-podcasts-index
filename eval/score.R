source("eval/eval.R") # brings in some Data and Functions

library(elastic)
library(tidyverse)

con <- connect()

# res <- topics$query[topic_num] %>% 
#   Search(con, "podcasts", q = .)


# Some more functions -----------------------------------------------------
# TODO: move elsewhere

get_query(2)

# this is where to write new DSL
get_search <- function(topic, ...) {
  
  query <- get_query(topic)
  
  query_req <- list(
    "size" = 50,
    "_source" = list(
      "episode_filename_prefix",
      "episode_name",
      "episode_description"
    ),
    "query" = list(
      "combined_fields" = list(
        "fields" = list("episode_description", "episode_name"),
        "query" = query,
        "minimum_should_match" = "50%"
      )
    )
  )
  
  Search(con, "podcasts", body = query_req)
}
  
res <- get_search(2)
res

get_ids <- function(res, topic) {
  if (res[['hits']][['total']] == 0) {
    stop("No results from Elastic!!!")
  } else {
    res[['hits']][['hits']] %>% 
      map_chr(~ .[['_source']][['episode_filename_prefix']]) %>% 
      paste0("spotify:episode:", .) %>% # this needs to really match down to the segment level
      data.frame(topic = topic, id = ., result = T)
  }
}

ids <- get_ids(res, 2)
ids

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
topic_num <- 2
get_query(topic_num)
ids <- get_search(topic_num) %>% 
  get_ids(topic_num)

ids %>% score_ids(topic_num)
ids

scores <- list()
for (t in unique(qrels$topic)) {
  scores[[t]] <- get_search(t) %>% 
    get_ids(t) %>% 
    score_ids() %>% 
    data.frame(topic = t, score = .)
}

# figure out why some scores are NULL and being dropped
null_topics <- scores %>% map_lgl(is.null) %>% which()
scores = scores[-null_topics]

dat_scores <- bind_rows(scores) %>% 
  inner_join(topics)

library(ggbeeswarm)
p <- ggplot(data = dat_scores, aes(x = "1", y =score, color = type, label = topic, query = query, group = 1)) +
  geom_quasirandom() +
  stat_summary(geom = "crossbar", fun.data = mean_cl_boot, aes(color="Average")) +
  labs(x = "All topics", y = "nDCG@10", title = "no MM")

plotly::ggplotly(p)
