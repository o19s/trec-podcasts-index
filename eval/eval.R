library(elastic)
suppressPackageStartupMessages(library(tidyverse, warn.conflicts = FALSE))

topics <- read.csv("data/topics.csv")
tests <- read.csv("data/test.csv")

# pull out the query string by topic ID (1-58 are available)
get_query <- function(top) {
  bind_rows(topics,tests) %>% 
    filter(topic == top) %>% 
    pull(query)
}

qrels <- read.csv("data/qrels.csv")

# DCGs --------------------------------------------------------------------

dcg <- function(docs, at = 10) {
  if (length(docs) < at) {
    doc_subset <- c(docs, rep(0, times = 10 - length(docs)))
    doc_subset <- doc_subset[1:at]
  } else {
    doc_subset <- docs[1:at]
  }
  scores_to_sum <- vector("numeric", length(doc_subset))
  for (i in seq_along(doc_subset)) {
    scores_to_sum[i] <- doc_subset[i] / log(i + 1, base = 2)
  }
  sum(scores_to_sum)
}

ndcg <- function(docs, docs_ideal, at = 10) {
  real <- dcg(docs, at)
  ideal <- dcg(docs_ideal, at)
  real / ideal
}

# Elastic helpers ---------------------------------------------------------

get_search <- function(topic, con, ...) {
  body_scaffold <- list(
    "size" = 100,
    "_source" = list(
      "text",
      "episode",
      "startTime"))
  
  query_string <- get_query(topic)
  body_scaffold[['query']] = query_template(query_string)
  
  x <- Search(con, "podcasts", body = body_scaffold)
  x[['topic']] = topic
  x
}

get_search_filtered <- function(topic, con, ids, ...) {
  body_scaffold <- list(
    "size" = 100,
    "_source" = list(
      "text",
      "lookup",
      "episode",
      "startTime"))
  
  query_string <- get_query(topic)
  body_scaffold[['query']] = query_template(query_string, ids)
  
  x <- Search(con, "podcasts", body = body_scaffold)
  x[['topic']] = topic
  x
}

get_ids <- function(res) {
  topic <- res[['topic']]
  
  if (res[['hits']][['total']][['value']] == 0) {
    warning("No results from Elastic!!!")
    data.frame(topic = topic, id = "missing", doc_score = NA, result = F)
  } else {
    ids <- res[['hits']][['hits']] %>% 
      map_chr(~ paste0(.[['_source']][['episode']], "_", .[['_source']][['startTime']])) %>% 
      paste0("spotify:episode:", ., ".0")
    scores <-  res[['hits']][['hits']] %>% 
      map_dbl(~.[['_score']])
    
    data.frame(topic = topic, id = ids, es_score = scores / max(scores), result = T)
  }
}

score_ids <- function(ids) {
  topic <- unique(ids$topic)
  
  topic_qrels <- qrels %>% 
    filter(topic %in% unique(ids$topic)) %>% 
    arrange(desc(grade))
  
  if (nrow(topic_qrels) == 0) {
    return(NA)
  }
  
  ids %>% 
    left_join(topic_qrels, by = c("topic", "id")) %>% 
    pull(grade) %>% 
    replace_na(0) %>% 
    ndcg(topic_qrels$grade)
}

#' Iterate over unique topics in `qrels`.
#' 
#' @return Dataframe
score_all <- function(qrels, topics, con, ...) {
  scores <- list()
  for (t in unique(qrels$topic)) {
    scores[[t]] <- get_search(t, con) %>% 
      get_ids() %>% 
      score_ids() %>% 
      data.frame(topic = t, ndcg = .)
  }
  scores %>%
    bind_rows() %>% 
    # mutate(ndcg = ndcg / max(ndcg)) %>% 
    inner_join(topics, by = "topic") %>% 
    select(-description)
}


# plots -------------------------------------------------------------------

score_summary <- function(scores) {
  scores %>% 
    group_by(type) %>% 
    summarise(grp = mean(ndcg)) %>% 
    mutate(overall = mean(scores$ndcg)) %>% 
    pivot_wider(names_from = type, values_from = grp)
}

crossbar_plot <- function(dat, ...) {
  p <- ggplot(data = dat, aes(x = type, y = ndcg, color = type, label = topic,
                              query = query, group = type)) +
    stat_summary(geom = "crossbar", fun.data = mean_cl_boot, aes(color="Average")) +
    ggbeeswarm::geom_quasirandom() +
    labs(...)
  
  plotly::ggplotly(p)
}

