import json
import math
import pickle
import requests
import statistics
import time
import torch

from scipy import spatial
from tqdm import tqdm
from sentence_transformers import SentenceTransformer

def sim_sort(a):
    return a['similarity']

# Load msmarco sentence transformer
print('Loading transformer model')
model = SentenceTransformer('sentence-transformers/msmarco-distilbert-base-v2', device='cuda')

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
        d = math.log2(i + 2)
        n = math.pow(2, int(vals[i])) - 1
        dcg += (n / d) if d > 0 else 0.0

    return dcg

def eval(query, top_docs):
    with open('data/2020_query_map.json') as src:
        query_lookup = json.load(src)

    target_query = query_lookup[query]

    ratings = []
    rating_lookup = {}

    with open('data/podcasts_2020_test.qrels') as src:
        for line in src.readlines():
            line = line.strip()
            if line is None or len(line) == 0:
                continue

            elements = line.split()

            if elements[0] != target_query:
                continue

            episode = elements[2]
            rating = int(elements[3])
            ratings.append({
                'episode': episode,
                'rating': rating
                })

            rating_lookup[episode] = rating

    # NDCG Stuff
    k = 10
    missing_score = 0

    ideal = [missing_score] * len(ratings)
    actual = [missing_score] * k

    # Setup best possible ideal
    for idx, rating in enumerate(ratings):
        ideal[idx] = rating['rating']

    ideal.sort(reverse=True)
    ideal = ideal[:k]

    # Setup the actual
    for idx, hit in enumerate(top_docs[:10]):
        # Conversion to spotify format, check w/ Nate on rounding
        to_check = 'spotify:episode:{}.0'.format(hit['id'])

        if to_check in rating_lookup:
            actual[idx] = rating_lookup[to_check]

    n = DCG(actual)
    d = DCG(ideal)

    return (n / d) if d > 0 else 0.0



def execute_query(query):
    # Query to run
    query_sample = [query]

    # Rank top 1000 docs
    top_docs = []

    es_query = {
        'size': 250,
        'query': {
            'bool': {
                'must': [
                    {
                        'combined_fields': {
                            'query': query,
                            'minimum_should_match': '1',
                            'fields': ['text^2']
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
    DESC_BOOST_BASE = 1

    to_boost_desc = {}
    to_boost_text = {}

    with open('data/2020_query_map.json') as src:
        query_lookup = json.load(src)

    target_query = query_lookup[query]
    with open('cache/angles-{}.pickle'.format(target_query), 'rb') as src:
        angles = pickle.load(src)


    for angle in angles[:ANGLE_N]:
        to_boost_text[angle['id']] = angle['similarity'] * TEXT_BOOST_BASE

    with open('cache-desc/angles-{}.pickle'.format(target_query), 'rb') as src:
        angles = pickle.load(src)

    for angle in angles[:ANGLE_N]:
        to_boost_text[angle['id']] = angle['similarity'] * DESC_BOOST_BASE

    resp = requests.post('http://localhost:9200/podcasts/_search', json=es_query).json()
    for hit in resp['hits']['hits']:
        doc = hit['_source']
        top_docs.append({'id': hit['_id'], 'score': hit['_score']})

    # Boost and resort
    for idx, doc in enumerate(top_docs):
        # Text embed boost
        if doc['id'] in to_boost_text:
            doc['score'] += (1 / (idx + 1)) * to_boost_text[doc['id']]

        # Desc embed boost
        to_check = doc['id'].split('_')[0] + '_0'
        if to_check in to_boost_desc:
            doc['score'] += (1 / (idx + 1)) * to_boost_desc[to_check]

    # Comment out to disable embed boosting phase
    #top_docs.sort(reverse=True, key=score_key)

    # Sneak peek
    score = eval(query, top_docs)
    print('Computed nDCG: {}'.format(score))

    return {
        'query': query,
        'docs': top_docs[:10],
        'score': score
    }

summary = []
with open('data/2020_queries.json') as src:
    queries = json.load(src)

for query in queries['queries']:
    summary.append(execute_query(query))

scores = []
for result in summary:
    scores.append(result['score'])
    print('Results for query: {}'.format(result['query']))
    print('NDCG: {}'.format(result['score']))
    print()

    '''
    for doc in result['docs']:
        print(get_meta(doc))

    print()
    '''

print('Overall nDCG performance: {}'.format(statistics.mean(scores)))

