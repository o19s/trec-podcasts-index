# TREC Podcasts

## Source data

Spotify provided 100k Podcasts with metadata (`podcast_summary` index) and transcripts (`podcasts_transcripts` index). In the `podcast_summary` index, each document is a episode, with fields for Show Title, Show Description, Episode Title and Episode Description. In the `podcasts_transcripts` index each document is a two minute segment's transcript, with fields TBD.


### data/ directory

You are expected to have downloaded the dataset from G-Drive and have the `transcripts/` directory unzipped sitting under `data/`. You should also have the `metadata.tsv` (also on G-Drive) sitting under `data/`.

## R dependencies

The indexers are written in R. To run them you should have [R version 4.0+](https://www.r-project.org/) installed.

This code will install required R libraries.

```
Rscript reqs.R
```

## Elasticsearch via Docker

```
docker-compose up
```

It also includes Kibana for convenience. 



Both services are available on the default ports.

* Elasticsearch - [localhost:9200](http://localhost:9200)
* Kibana - [localhost:5601](http://localhost:5601)


## Index

To create (or re-create if already exists) the `podcasts_summary` index: 

```
Rscript index_summary.R
```

The schema is defined in `schema_summary.json`. So make any field changes there

For the `podcasts_transcripts: (a much longer endeavor)

To create (or re-create if already exists) the `podcasts_summary` index: 

```
Rscript index_transcript.R
```

