# TREC Podcasts

## Source data

Spotify provided 100k Podcasts with metadata (`podcast_summary` index) and transcripts (`podcasts_transcripts` index). In the `podcast_summary` index, each document is a episode, with fields for Show Title, Show Description, Episode Title and Episode Description. In the `podcasts_transcripts` index each document is a two minute segment's transcript, with fields TBD.


### data/ directory

You are expected to have downloaded the [data files from G-Drive](https://drive.google.com/drive/u/0/folders/1P6COi4AL3aBgNOrjj80FP4V8m_F-5sk0) (requires OSC account) and have this directory structure:

```
data/
├── metadata.tsv
├── podcasts_2020_topics_test.xml
├── podcasts_2020_topics_train.xml
├── podcasts_2021_topics_test.xml
├── qrels.R
├── qrels.csv
├── topics.R
├── topics.csv
└── transcripts
    ├── 0
    ├── 1
    ├── 2
    ├── 3
    ├── 4
    ├── 5
    ├── 6
    └── 7
```

Items denoted with `###` are from TREC and must be downloaded from G-Drive.

The R scripts generate a similarly named CSV file to make data frames readily available. Run:

```
Rscript qrels.R
```

To generate `qrels.csv` once the required TREC files are downloaded.


## R dependencies

The indexers and data readers are written in R. To run them you should have [R version 4.0+](https://www.r-project.org/) installed.

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

