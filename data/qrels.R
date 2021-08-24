library(dplyr)

bind_rows(
  read.table("https://trec.nist.gov/data/podcast/podcasts_2020_train.1-8.qrels",
             sep = "\t"),
  read.table("https://trec.nist.gov/data/podcast/podcasts_2020_test.qrels",
             sep = " ")
) %>% 
  setNames(c("topic", "drop", "id", "grade")) %>% 
  select(-drop) %>% 
  write.csv("data/qrels.csv", row.names = F)
