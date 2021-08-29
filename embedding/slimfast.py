import pickle

def extract_id(doc):
    return '{}_{}'.format(doc['_source']['episode'], doc['_source']['startTime'])

all_embeddings = []
for i in range(0, 368):
    with open('output/trec_embeds_{}.pickle'.format(i), 'rb') as src:
        docs = pickle.load(src)

        for doc in docs:
            all_embeddings.append({
                'id': extract_id(doc),
                'text_embedding': doc['text_embedding']
            })

print('Writing slimmed down embeddings (ID and embedding data only)')
with open('output/trec_embed_100k.pickle', 'wb') as out:
    pickle.dump(all_embeddings, out)
