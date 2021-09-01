import requests

total = 0
missing = 0

with open('data/podcasts_2020_test.qrels') as src:
    for line in src.readlines():
        elements = line.split()
        total += 1

        episode = elements[2].split(':')[2].split('_')
        epid = episode[0]
        time = float(episode[1])

        query = {
            'query': {
                'bool': {
                    'must': [
                        {'match': {'episode.keyword': epid}},
                        {'match': {'startTime': time}}
                    ]
                }
            }
        }
        resp = requests.post('http://localhost:9200/podcasts/_search', json=query).json()

        if 'hits' not in resp['hits'] or len(resp['hits']['hits']) == 0:
            missing += 1
            print('{} {} not found!'.format(elements[3], elements[2]))

print('Total ratings: {}'.format(total))
print('Missing ratings: {}'.format(missing))
print('Missing rate: {:2f}'.format((missing/total)))
