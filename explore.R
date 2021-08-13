library(elastic)
library(jsonlite)
library(magrittr)
library(tidyverse)


# Set up ES ---------------------------------------------------------------


# Read in all files -------------------------------------------------------
shards <- dir('data/transcripts', full.names = T)
shards


dirs <- dir(shards[6], full.names = T)
dirs
all_dirs <- map(shards, ~dir(.x, full.names = T)) %>% unlist()

shows <- dir(dirs[11], full.names = T)
shows
all_shows <- map(all_dirs, ~dir(.x, full.names = T)) %>% unlist()


ptm <- proc.time()

# read once save a CPU
meta <- read_tsv('data/metadata.tsv') %>% 
  select(-show_uri, -language, -rss_link, -episode_uri)

for (show in all_shows[1]) {
  show_name <- gsub('.*/', '', show)
  show_name
  files <- dir(show, full.names = T)
  files
  
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
           minute_chunk = startTime %/% 60)
  
  # Chunk into 2 minute sections --------------------------------------------
  big_dat %<>% 
    group_by(show, episode, minute_chunk) %>% 
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(word, collapse = " "))
  big_dat %<>% 
    ungroup() %>% 
    mutate(id1 = rep(1:(nrow(big_dat)/2), each = 2, length.out = nrow(big_dat)),
           id2 = c(0,rep(1:(nrow(big_dat)/2), each = 2, length.out = nrow(big_dat)-1)))
  big_dat1 <- big_dat %>% 
    group_by(show, episode, id1) %>% 
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(text, collapse = " ")) %>% 
    ungroup() %>% 
    select(-id1)
  big_dat2 <- big_dat %>% 
    group_by(show, episode, id2) %>% 
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(text, collapse = " ")) %>% 
    ungroup() %>% 
    select(-id2)
  
  # Meta info join ----------------------------------------------------------
  big_dat1 %<>% inner_join(meta, .,
                           by = c('show_filename_prefix' = 'show',
                                  'episode_filename_prefix' = 'episode'))
  big_dat2 %<>% inner_join(meta, .,
                           by = c('show_filename_prefix' = 'show',
                                  'episode_filename_prefix' = 'episode'))

  # Index to ES -------------------------------------------------------------
  docs_bulk(x, big_dat1, 'trec-podcasts')
  docs_bulk(x, big_dat2, 'trec-podcasts')
}

proc.time() - ptm

