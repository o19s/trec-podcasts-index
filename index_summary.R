library(elastic)
library(tidyverse)

# ES setup ----------------------------------------------------------------
x <- connect()
schema <- jsonlite::read_json('schema_summary.json')
if (index_exists(x, 'podcasts_summary')) resp <- index_delete(x, 'podcasts_summary')
resp <- index_create(x, 'podcasts_summary', body = schema)


meta <- read_tsv('data/metadata.tsv', col_types = cols()) %>%
  select(-show_uri, -language, -rss_link, -episode_uri)

resp <- docs_bulk(x, meta, 'podcasts_summary', chunk_size = 1e4)
