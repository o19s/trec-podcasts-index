# library(parallel)
library(magrittr)
library(elastic)
library(jsonlite)
library(tidyverse)

# ES setup ----------------------------------------------------------------
x <- connect()
# schema <- jsonlite::read_json('schema_transcript.json')
# if (index_exists(x, 'podcasts')) index_delete(x, 'podcasts')
# index_create(x, 'podcasts', body = schema)

meta <- read_tsv('data/metadata.tsv', col_types = cols()) %>%
  select(-show_uri, -language, -rss_link, -episode_uri)


# File read in ------------------------------------------------------------
shards <- dir('data/transcripts', full.names = T)
all_dirs <- map(shards, ~dir(.x, full.names = T)) %>% unlist()
all_shows <- map(all_dirs, ~dir(.x, full.names = T)) %>% unlist()

# ptm <- proc.time()

show <- sample(all_shows, size = 1)
show <- 'data/transcripts/0/H/show_0H5UiFLZuyCtpnfchdYOvF'

upload_episode <- function (show, con = x) {

  show_name <- gsub('.*/', '', show)
  files <- dir(show, full.names = T)
  
  big_dat <- list()
  for (f in files) {
    episode <- gsub('.*/(.*)\\.json', '\\1', f)
    
    dat <- fromJSON(f)
    dat <- dat[['results']][['alternatives']]
    mask <- map_lgl(dat, ~dim(.)[2] == 3)
    dat <- dat[mask]
    rm(mask)
    dat <- map_df(dat, ~.[['words']])
    
    dat$show <- show_name
    dat$episode <- episode
    
    big_dat[[f]] <- dat
  }
  
  big_dat <- bind_rows(big_dat, .id = 'file') %>% 
    mutate(file = fct_inorder(file) %>% as.numeric,
           across(.cols = matches("Time"), ~as.numeric(gsub("s", "", .))),
           minute_chunk = startTime %/% 60) %>% 
    group_by(show, episode, minute_chunk) %>% 
    summarise(startTime = (min(startTime) %/% 60) * 60,
              endTime = max(endTime),
              text = paste(word, collapse = " "),
              .groups = "drop") %>% 
    inner_join(meta, by = c("show" = "show_filename_prefix",
                            "episode" = "episode_filename_prefix")) %>%
    arrange(startTime)
  
  big_dat %<>%
    group_by(episode) %>% 
    mutate(id1 = startTime %/% 120,
           id2 = (startTime - 60) %/% 120) %>% 
    ungroup()
  
  # Chunk into 2 minute sections --------------------------------------------
  
  big_dat1 <- big_dat %>% 
    group_by(show, episode, show_name, show_description, episode_name, episode_description, id1) %>% 
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(text, collapse = " "),
              .groups = "drop") %>% 
    ungroup() %>%
    select(-id1)
  
  out <- docs_bulk(con, big_dat1, 'podcasts', quiet = T, chunk_size = 1e4)
  rm(big_dat1, out)
  
  big_dat2 <- big_dat %>% 
    filter(id2 != -1) %>% 
    group_by(show, episode, show_name, show_description, episode_name, episode_description, id2) %>% 
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(text, collapse = " "),
              .groups = "drop") %>% 
    ungroup() %>%
    select(-id2)
  
  out <- docs_bulk(con, big_dat2, 'podcasts', quiet = T, chunk_size = 1e4)
}

system.time(
  lapply(all_shows, upload_episode)
)

# system.time(
#   mclapply(all_shows[1:18], upload_episode, mc.cores = 2)
# )

# proc.time() - ptm
