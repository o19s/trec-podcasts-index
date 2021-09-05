import csv
import json
import math
import pickle
import requests
import statistics
import time
import torch

from scipy import spatial
from tabulate import tabulate
from tqdm import tqdm
from sentence_transformers import SentenceTransformer

def sim_sort(a):
    return a['similarity']

ES_HOST = 'http://localhost:9200'
INDEX_NAME = 'podcasts'

def get_meta(doc):
    episode = doc['id'].split('_')[0]

    query = {
        'size': 1,
        'query': {
            'match': {
                'episode.keyword': episode
            }
        }   
    }
    resp = requests.post('{}/{}/_search'.format(ES_HOST, INDEX_NAME), json=query).json()
    episode_title = resp['hits']['hits'][0]['_source']['episode_name']

    return '{} -- {} ({})'.format(doc['similarity'], episode_title, doc['id'])

def score_key(a):
    return a['score']

def DCG(vals):
    dcg = 0
    for i in range(len(vals)):
        n = int(vals[i])
        d = math.log2(i + 2)
        dcg += (n / d) if d > 0 else 0.0

    return dcg

def eval(query, top_docs):
    query_lookup = {}
    with open('data/topics.csv', encoding='utf8') as src:
        reader = csv.DictReader(src)
        for row in reader:
            query_lookup[row['query']] = row['topic']

    target_topic = query_lookup[query]
    
    ratings = []
    rating_lookup = {}

    with open('data/qrels.csv') as src:
        reader = csv.DictReader(src)

        for row in reader:
            if row['topic'] != target_topic:
                continue

            episode = row['id']
            rating = row['grade']
            ratings.append({
                'episode': episode,
                'rating': rating
                })

            rating_lookup[episode] = rating

    if len(ratings) == 0:
        print('No rating for topic {} - {}'.format(target_topic, query))

    # NDCG Stuff
    k = 10
    missing_score = 0.0

    ideal = [missing_score] * len(ratings)
    actual = [missing_score] * k

    
    # Setup best possible ideal
    for idx, rating in enumerate(ratings):
        ideal[idx] = rating['rating']

    ideal.sort(reverse=True)
    ideal = ideal[:k]

    # Setup the actual
    for idx, hit in enumerate(top_docs[:k]):
        # Conversion to spotify format, check w/ Nate on rounding
        to_check = 'spotify:episode:{}.0'.format(hit['id'])

        if to_check in rating_lookup:
            actual[idx] = rating_lookup[to_check]

    n = DCG(actual)
    d = DCG(ideal)

    return (n / d) if d > 0 else 0.0
        


def execute_query(query):
    # Rank top 1000 docs
    top_docs = []

    tokens = query.split()
    span_clauses = []
    for token in tokens:
        span_clauses.append({
            'span_term': {'text': token}
        })

    es_query = {
        'size': 250,
        'query': {
            'bool': {
                'must': [
                    {
                        'combined_fields': {
                            'query': query,
                            'minimum_should_match': '1',
                            'fields': ['text']
                        }
                    }
                ],
                'should': [
                ]
            }
            
        }
    }

    # Experimental boost by angle if in top N
    ANGLE_N = 10 
    TEXT_BOOST_BASE = 1000
    DESC_BOOST_BASE = 0

    to_boost_desc = {}
    to_boost_text = {}

    query_lookup = {}
    with open('data/topics.csv', encoding='utf8') as src:
        reader = csv.DictReader(src)
        for row in reader:
            query_lookup[row['query']] = int(row['topic'])


    target_query = query_lookup[query]
    with open('cache/angles-{}.pickle'.format(target_query), 'rb') as src:
        angles = pickle.load(src)

    top_docs = angles[:100]
    doc_dict = {}
    for doc in top_docs:
        doc_dict[doc['id']] = doc

    # Filter to top N angles
    es_query['query']['bool']['filter'] = {
        'terms': {
            'lookup.keyword': [x['id'] for x in top_docs]
        }
    }

    
    resp = requests.post('http://localhost:9200/podcasts/_search', json=es_query).json()
    top_score = resp['hits']['hits'][0]['_score'] if len(resp['hits']['hits']) > 0 else 0

    for idx, hit in enumerate(resp['hits']['hits']):
        if hit['_source']['lookup'] in doc_dict:
            sim = doc_dict[hit['_source']['lookup']]['similarity']
            doc_dict[hit['_source']['lookup']]['similarity'] = sim + 1.0 * (hit['_score'] / top_score)

    top_docs.sort(reverse=True, key=sim_sort)

    # Sneak peek
    score = eval(query, top_docs)
    print('Computed nDCG: {}'.format(score))

    return {
        'query': query,
        'docs': top_docs[:10],
        'score': score 
    }

summary = []
with open('data/topics.csv', encoding='utf8') as src:
    reader = csv.DictReader(src)

    no_rating_topics = [47, 50]

    processed = 0
    for row in reader: 
        if int(row['topic']) in no_rating_topics:
            continue

        summary.append(execute_query(row['query']))
        processed += 1

tab_data = []
scores = []

for result in summary:
    scores.append(result['score'])
    tab_data.append([result['query'], result['score']])


non_zero_scores = [score for score in scores if score > 0]
print(statistics.mean(non_zero_scores))
print(len(summary))
print(tabulate(tab_data))
print(sum(scores) / 50)
print('Overall nDCG performance: {}'.format(statistics.mean(scores)))

