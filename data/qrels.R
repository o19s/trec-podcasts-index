library(dplyr)

bind_rows(
  read.table("https://trec.nist.gov/data/podcast/podcasts_2020_train.1-8.qrels",
             sep = "\t"),
  read.table("https://trec.nist.gov/data/podcast/podcasts_2020_test.qrels",
             sep = " ")
) %>% 
  write.csv("data/qrels.csv")
