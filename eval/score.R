source("eval/eval.R") # brings in some Data and Functions

library(elastic)
suppressPackageStartupMessages(library(tidyverse, warn.conflicts = FALSE))

con <- connect()

# Some more functions -----------------------------------------------------
# TODO: move elsewhere

# this is where to write new DSL
get_search <- function(topic, ...) {
  
  query <- get_query(topic)
  
  query_req <- list(
    "size" = 50,
    "_source" = list(
      "episode",
      "startTime",
      "episode_name",
      "episode_description",
      "text"
    ),
    "query" = list(
      "combined_fields" = list(
        "fields" = list("episode_description", "episode_name", "text^2"),
        "query" = query,
        "minimum_should_match" = "100%"
      )
    )
  )
  
  x <- Search(con, "podcasts", body = query_req)
  x[['topic']] = topic
  x
}

get_ids <- function(res) {
  topic <- res[['topic']]
  
  if (res[['hits']][['total']] == 0) {
    warning("No results from Elastic!!!")
    data.frame(topic = topic, id = NA, id = NA, result = F)
  } else {
    res[['hits']][['hits']] %>% 
      map_chr(~ paste0(.[['_source']][['episode']], "_", .[['_source']][['startTime']])) %>% 
      paste0("spotify:episode:", ., ".0") %>%
      data.frame(topic = topic, id = ., result = T)
  }
}

score_ids <- function(ids) {
  
  topic <- unique(ids$topic)
  
  topic_qrels <- qrels %>% 
    filter(topic %in% unique(ids$topic)) %>% 
    # mutate(id = gsub("_.*", "", id)) %>% 
    # group_by(topic, id) %>% 
    # summarise(grade = max(grade), .groups = 'drop') %>% 
    arrange(desc(grade))
  
  ids %>% 
    left_join(topic_qrels, by = c("topic", "id")) %>% 
    pull(grade) %>% 
    replace_na(0) %>% 
    c(topic_qrels$grade) %>% 
    ndcg()
}

# All topics --------------------------------------------------------------

scores <- list()
for (t in unique(qrels$topic)) {
  scores[[t]] <- get_search(t) %>% 
    get_ids() %>% 
    score_ids() %>% 
    data.frame(topic = t, score = .)
}

dat_scores <- bind_rows(scores) %>% 
  inner_join(topics, by = "topic")

library(ggbeeswarm)
p <- ggplot(data = dat_scores, aes(x = "1", y =score, color = type, label = topic, query = query, group = 1)) +
  geom_quasirandom() +
  stat_summary(geom = "crossbar", fun.data = mean_cl_boot, aes(color="Average")) +
  labs(x = "All topics", y = "nDCG@10", title = "no MM")

# plotly::ggplotly(p)

print(paste("Average nDCG@10:", round(mean(dat_scores$score, na.rm = T), 3)))

      