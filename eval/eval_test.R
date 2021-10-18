library(tidyverse)


all <- read_table("~/Downloads/_retrieval_evaluations_trec_trec30_tables_podcast-QR.txt",
                skip = 1) %>% 
  set_names("topic", "ndcg", "drop1", "drop2") %>% 
  select(-drop1, -drop2) %>% 
  separate(ndcg, c("min", "med", "max"), sep = " ") %>% 
  mutate(med = as.numeric(med),
         max = as.numeric(max),
         min = as.numeric(min),)
all

read_run <- . %>% 
  read_tsv(col_names = F) %>% 
  set_names(c("key", "topic", "value")) %>% 
  filter(key == "ndcg_cut_30") %>%
  mutate(value = as.numeric(value))


us <- read_run("~/Downloads/osc_tok_vec.QR.eval")
us

runs <- dir("~/Downloads/", "osc_", full.names = T) %>% 
  set_names(gsub(".*osc_(.*)\\.QR.*", "\\1", .)) %>% 
  map_dfr(read_run, .id = "run")

us$value %>% mean()

all$med %>% mean()
all$max %>% mean()


ggplot(all, aes(topic, med)) +
  geom_line(aes(color = "Median (all runs)")) +
  geom_line(aes(y = max, color = "Max (all runs)")) +
  geom_line(aes(y = min, color = "Min (all runs)")) +
  geom_line(data = runs, aes(y = value, group = 1, color = "OSC")) +
  facet_wrap(~run) +
  scale_color_manual(values = c("darkred", "grey", "darkblue", "black"))
  labs(title = "OSC at TREC-Podcasts 2021",
       subtitle = "4 runs, 1 per panel",
       y = "nDCG@30",
       x = "Topic #")


runs %>%
  group_by(run) %>% 
  summarise(avg = mean(value)) %>% 
  bind_rows(
    data.frame(
      "run" = c("median all runs", "max all runs"),
      "avg" = c(all$med %>% mean(), all$max %>% mean())
    )
  )
  
