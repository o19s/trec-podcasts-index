import pickle
import requests
import time
from tqdm import tqdm
from sentence_transformers import SentenceTransformer

# Load msmarco sentence transformer
model = SentenceTransformer('sentence-transformers/msmarco-distilbert-base-v2', device='cuda')

ES_HOST = 'http://localhost:9200'
INDEX_NAME = 'podcasts'

BATCH_SIZE = 10000

query = {
    "size": BATCH_SIZE
}

scroll_query = {
    'scroll': '3m',
    'scroll_id': None, # To be filled each loop
}

first_loop = True

print('Reading in all docs for processing')
start_time = time.time()

batch_num = 0
processed = 0

ROUGH_COUNT = 3680000

for i in tqdm(range(0, ROUGH_COUNT, BATCH_SIZE)):
    if first_loop:
        resp = requests.post('{}/{}/_search?scroll=3m'.format(ES_HOST, INDEX_NAME), json=query).json()
        first_loop = False
    else:
        resp = requests.post('{}/_search/scroll'.format(ES_HOST), json=scroll_query).json()

    if 'hits' not in resp['hits'] or len(resp['hits']) == 0:
        break

    scroll_query['scroll_id'] = resp['_scroll_id']
    
    batch = resp['hits']['hits']

    # Truncate text to 512 tokens for embedding
    subset = [' '.join(x['_source']['text'].split()[:512]) for x in batch]

    # Do the embedding
    embeddings = model.encode(subset)

    # Inject embedding back into docs
    for idx, embedding in enumerate(embeddings):
        batch[idx]['text_embedding'] = embedding


    # Write to disk
    with open('output/trec_embeds_{}.pickle'.format(batch_num), 'wb') as out:
        pickle.dump(batch, out)

    batch_num += 1
