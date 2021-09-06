#' Baseline strategy / template
#' 
#' A ES connection, `con` and a function `query_template()` must be defined in each score_X.R script if
#' `get_search()` is being used. `rescore_template` will need to be added in a
#' similar fashion
#' 
#'
library(magrittr)
source("eval/eval.R")


con <- elastic::connect()


query_template <- function(string, vids) {
  list(
    "bool" = list(
      "should" = list(
        "match" = list(
          "text" = string
        )
      ),
      "filter" = list(
        "terms" = list(
          "lookup.keyword" = vids
        )
      )
    )
  )
}

# query_template and con must be set before
source("eval/eval.R")


for (t in unique(tests$topic)) {
  print(t)
  glue::glue("embedding/cache/angles-{t}.json")
  vectors <-  glue::glue("embedding/cache/angles-{t}.json") %>% 
    jsonlite::read_json() %>% 
    .[1:1000]
}

vectors <-  glue::glue("embedding/cache/angles-{t}.json") %>% 
  jsonlite::read_json() %>% 
  .[1:1000]

es_rescore <- function(topic, rescore = T) {
  top <- topic
  
  vectors <-  glue::glue("embedding/cache/angles-{topic}.json") %>% 
    jsonlite::read_json() %>% 
    .[1:1000]
  
  vec_score <- data.frame(
    id = map_chr(vectors, ~ .$id) %>% paste0("spotify:episode:", ., ".0"),
    vector_score = map_dbl(vectors, ~ .$similarity)
  )
  
  vec_ids <- as.list(vec_score$id)
  
  if (rescore) {
    dat <- get_search_filtered(topic, con, vec_ids) %>% 
      get_ids() 
    
    if (dat$id[1] == "missing") {
      return(
        vec_score %>% 
        mutate(topic = top,
               final = vector_score)
      )
    } else {
      return( dat %>% 
        left_join(vec_score, ., by = "id") %>%
        replace_na(list(es_score = 0)) %>% 
        ungroup() %>% 
        mutate(final = vector_score + es_score,
               topic = top) %>% 
        arrange(desc(final)) )
      # %>%
      #   score_ids()
    }
    
  } else {
    return( vec_score %>% 
      mutate(topic = top,
             final = vector_score)
    )
    # %>%
    #   score_ids()
  }
}

rescores <- list()
raw <- list()
for (t in unique(tests$topic)) {
  rescores[[as.character(t)]] <- es_rescore(t)
  raw[[as.character(t)]] <- es_rescore(t, F)
}

map_df(rescores, function(x) {
  y <- x %>% 
    slice(1:100) %>% 
    mutate(QTYPE = "QR",
           RANK = 1:100,
           RUNID = "osc_vec_tok") %>% 
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
  write_tsv("submission/osc_vec_tok.tsv", col_names = F)

map_df(raw, function(x) {
  y <- x %>% 
    slice(1:100) %>% 
    mutate(QTYPE = "QR",
           RANK = 1:100,
           RUNID = "osc_vector") %>% 
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
  write_tsv("submission/osc_vector.tsv", col_names = F)


dat <- data.frame(topic = names(rescores),
           rescore_ndcg = unlist(rescores),
           raw_ndcg = unlist(raw)) %>% 
  mutate(topic = as.numeric(topic)) %>% 
  inner_join(topics) %>% 
  select(-description) %>% 
  arrange(raw_ndcg) %>% 
  mutate(topic = fct_inorder(as.character(topic)))

avg_lines <- dat %>%
  group_by(type) %>% 
  summarise(avg_vec = mean(raw_ndcg),
            avg_rescore = mean(rescore_ndcg)) %>% 
  gather("key", "value", -type)

p_pre <- ggplot(dat, aes(y = topic)) +
  geom_point(aes(x = rescore_ndcg, color = "SBERT base")) +
  geom_point(aes(x = raw_ndcg, color = "Token rescore")) +
  geom_vline(data = avg_lines, aes(xintercept = value, color = key))+
  facet_grid(type ~ ., scales = "free_y", space = "free_y")

mean(dat$rescore_ndcg)
mean(dat$raw_ndcg)


