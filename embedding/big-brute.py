import json
import pickle
import requests
import time

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

def execute_query(query):
    # Query to run
    query_sample = [query]
    print('Encoding query: {}'.format(query_sample))
    embedded_query = model.encode(query_sample)[0]

    # Rank top 1000 docs
    top_docs = []

    print('Doing the ranking [this will take a while]')
    for i in tqdm(range(368)):
        with open('output_text/slim/trec_embed_{}.pickle'.format(i), 'rb') as src:
            embeddings = pickle.load(src)

        for embedding in embeddings:
            top_docs.append({
                'id': embedding['id'],
                'similarity': max(0, 1 - spatial.distance.cosine(embedded_query, embedding['text_embedding']))
            })

        top_docs.sort(reverse=True, key=sim_sort)
        top_docs = top_docs[:1000]

    return {
        'query': query,
        'docs': top_docs[:10]
    }

summary = []
with open('data/2020_queries.json') as src:
    queries = json.load(src)

# Debug: Remove or edit the slice for bigger runs
for query in queries['queries'][3:4]:
    summary.append(execute_query(query))

for result in summary:
    print('Results for query: {}'.format(result['query']))
    print()
    for doc in result['docs']:
        print(get_meta(doc))

    print()



