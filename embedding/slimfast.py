import pickle

def extract_id(doc):
    return '{}_{}'.format(doc['_source']['episode'], doc['_source']['startTime'])

for i in range(0, 368):
    with open('output/trec_embeds_{}.pickle'.format(i), 'rb') as src:
        docs = pickle.load(src)

        batch = []
        for doc in docs:
            batch.append({
                'id': extract_id(doc),
                'text_embedding': doc['text_embedding']
            })

        with open('output/slim/trec_embed_{}.pickle'.format(i), 'wb') as out:
            pickle.dump(batch, out)
