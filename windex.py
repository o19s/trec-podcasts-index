import csv
import json
import requests
import _thread as thread, queue, time
import time

from idx import chunker
from pathlib import Path
from tqdm import tqdm

'''

Chunker and indexer for TREC transcript data

OSC - 2021

'''

todo_pile = queue.Queue(maxsize=32)
ES_TARGET = 'http://localhost:9200/podcasts'

def process():
    while True:
        try:
            todo = todo_pile.get(timeout=180)
        except:
            print('Worker thread timed out')
            break

        segments = chunker.chunkit(todo['episode'], todo['ep_meta'])
        index(segments)

def index(docs):
    bulk_req = ''

    for doc in docs:
        bulk_req += json.dumps({
            'index': {
                '_index': 'podcasts',
                '_id': '{}_{}'.format(doc['episode_filename_prefix'], doc['startTime'])
            }
        })
        bulk_req += '\n'

        bulk_req += json.dumps(doc)
        bulk_req += '\n'

        requests.post('http://localhost:9200/_bulk', data=bulk_req, headers={'Content-Type': 'application/x-ndjson'})


with open('schema_transcript.json') as src:
    settings = json.load(src)

print('Deleting target: {}'.format(requests.delete(ES_TARGET).status_code))
print('Creating target: {}'.format(requests.put(ES_TARGET, json=settings).status_code))

metadata = {}

with open('data/metadata.tsv') as src:
    reader = csv.DictReader(src, delimiter='\t')

    for item in reader:
        show_filename_prefix = item['show_filename_prefix']
        show_name = item['show_name']
        show_description = item['show_description']
        episode_name = item['episode_name']
        episode_description = item['episode_description']
        episode_filename_prefix = item['episode_filename_prefix']
        episode_uri = item['episode_uri']

        metadata[episode_filename_prefix] = {
            'show_filename_prefix': show_filename_prefix,
            'show_name': show_name,
            'show_description': show_description,
            'episode_name': episode_name,
            'episode_description': episode_description,
            'episode_filename_prefix': episode_filename_prefix,
            'episode_uri': episode_uri
        }


motherload = list(Path('data/transcripts').rglob('*.json'))

print('Setting up the worker pool')

THREAD_WORKERS = 8
for i in range(THREAD_WORKERS):
    thread.start_new_thread(process, ())

for item in tqdm(motherload):
    filename = item.name.split('.')[0]

    with open(item) as src:
        episode = json.load(src)

    ep_meta = metadata[filename]
    todo_pile.put({'episode': episode, 'ep_meta': ep_meta})

while not todo_pile.empty():
    print('Still working on the last bits...')
    sleep(10)

print('All done')
