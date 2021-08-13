library(parallel)
library(magrittr)
library(elastic)
library(jsonlite)
library(forcats)
library(purrr)
library(dplyr)

# ES setup ----------------------------------------------------------------
x <- connect()
schema <- jsonlite::read_json('schema_transcript.json')
if (index_exists(x, 'podcasts_transcript')) index_delete(x, 'podcasts_transcript')
index_create(x, 'podcasts_transcript', body = schema)


# File read in ------------------------------------------------------------
shards <- dir('data/transcripts', full.names = T)
all_dirs <- map(shards, ~dir(.x, full.names = T)) %>% unlist()
all_shows <- map(all_dirs, ~dir(.x, full.names = T)) %>% unlist()

# ptm <- proc.time()

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
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(word, collapse = " "),
              .groups = "drop")
  
  big_dat %<>%
    mutate(id1 = rep(1:(nrow(big_dat)/2), each = 2, length.out = nrow(big_dat)),
           id2 = c(0,rep(1:(nrow(big_dat)/2), each = 2, length.out = nrow(big_dat)-1)))
  
  # Chunk into 2 minute sections --------------------------------------------
  
  big_dat1 <- big_dat %>% 
    group_by(show, episode, id1) %>% 
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(text, collapse = " "),
              .groups = "drop") %>% 
    ungroup() %>% 
    select(-id1)
  
  out <- docs_bulk(con, big_dat1, 'podcasts_transcript', quiet = T, chunk_size = 1e4)
  rm(big_dat1, out)
  
  big_dat2 <- big_dat %>% 
    group_by(show, episode, id2) %>% 
    summarise(startTime = min(startTime),
              endTime = max(endTime),
              text = paste(text, collapse = " "),
              .groups = "drop") %>% 
    ungroup() %>% 
    select(-id2)
  
  out <- docs_bulk(con, big_dat2, 'podcasts_transcript', quiet = T, chunk_size = 1e4)
}

system.time(
  lapply(all_shows, upload_episode)
)

# system.time(
#   mclapply(all_shows[1:18], upload_episode, mc.cores = 2)
# )

# proc.time() - ptm
