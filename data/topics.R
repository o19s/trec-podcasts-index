library(purrr)
library(XML)

topics <- list(
  "data/podcasts_2020_topics_test.xml",
  "data/podcasts_2020_topics_train.xml"
)

read_in <- function(x) {
  xmlParse(x) %>% 
    xmlToList() %>% 
    map_df(as.data.frame)
}

map_df(topics, read_in) %>% 
  rename(topic = num) %>% 
  write.csv(file = "data/topics.csv", row.names = F)
