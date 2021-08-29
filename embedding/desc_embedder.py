import pickle
import re
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

def sanitize(data):
    # Handle empty string, some episodes are missing data
    if data is None:
        return ''

    # Strip url
    return re.sub(r'http\S+', '', data)

    # TODO: Others?


def embed_format(payload):
    TOKEN_LIMIT = 512

    desc = sanitize(payload['_source']['episode_description'])
    name = sanitize(payload['_source']['episode_name'])

    tokens = desc.split() + name.split()

    return ' '.join(tokens[:TOKEN_LIMIT])

# Track which episodes have been processed so we don't do them multiple times
episode_tracker = {}

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
    slim_batch = []
    for todo in batch:
        episode = todo['_source']['episode']

        if episode not in episode_tracker:
            episode_tracker[episode] = True
            slim_batch.append(todo)
        else:
            continue

    # Run docs thru formatting/sanization 
    subset = [embed_format(x) for x in slim_batch]

    # Do the embedding
    embeddings = model.encode(subset)

    out_batch = []
    # Inject embedding back into docs
    for idx, embedding in enumerate(embeddings):
        out_batch.append({
            'id': '{}_{}'.format(slim_batch[idx]['_source']['episode'], slim_batch[idx]['_source']['startTime']),
            'desc_embeddings': embedding
        })

    # Write to disk
    with open('output/trec_desc_embeds_{}.pickle'.format(batch_num), 'wb') as out:
        pickle.dump(out_batch, out)

    batch_num += 1
