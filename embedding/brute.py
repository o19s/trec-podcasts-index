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

# Query to run
query_sample = ['horoscope reading cancer']
print('Encoding query: {}'.format(query_sample))
embedded_query = model.encode(query_sample)[0]

# Rank top 1000 docs
top_docs = []

print('Doing the ranking [this will take a while]')
iteration_time = time.time()
for i in range(368):
    with open('output/trec_desc_embeds_{}.pickle'.format(i), 'rb') as src:
        embeddings = pickle.load(src)

    for embedding in embeddings:
        top_docs.append({
            'id': embedding['id'],
            'similarity': max(0, 1 - spatial.distance.cosine(embedded_query, embedding['desc_embeddings']))
        })

    print('Batch {} done: {}s'.format(i, time.time() - iteration_time))
    iteration_time = time.time()
    
    top_docs.sort(reverse=True, key=sim_sort)
    top_docs = top_docs[:1000]

# Display results
print('TOP TEN HIT INFORMATION')
for hit in top_docs[:10]:
    print(hit['id'], hit['similarity'])
