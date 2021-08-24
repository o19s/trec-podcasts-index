topics <- read.csv("data/topics.csv")

# pull out the query by topicID (1-58)
get_query <- function(topic) {
  topics[topics$topic == topic, 'query']
}


qrels <- read.csv("data/qrels.csv")




dcg <- function(docs, at = 10) {
  doc_subset <- docs[1:at]
  scores_to_sum <- vector("numeric", length(doc_subset))
  for (i in seq_along(doc_subset)) {
    scores_to_sum[i] <- docs[i] / log(i + 1, base = 2)
  }
  sum(scores_to_sum)
}

ndcg <- function(docs, at = 10) {
  real <- dcg(docs, at)
  ideal <- dcg(sort(docs, decreasing = TRUE), at)
  real / ideal
}



