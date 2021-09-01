
def chunkit(tx, meta):
    batch = []

    curr_window = 1
    WINDOW_SIZE = 120
    tokens = []

    for thing in tx['results']:
        if len(thing['alternatives']) == 0:
            print('No alternatives found for ...')
            continue

        for alt in thing['alternatives']:
            if not alt.keys():
                continue

            for word in alt['words']:
                if float(word['startTime'][0:-1]) < (curr_window * WINDOW_SIZE):
                    tokens.append(word['word'])

                else:
                    batch.append({
                        'episode_description': meta['episode_description'],
                        'episode_filename_prefix': meta['episode_filename_prefix'],
                        'episode_name': meta['episode_name'],
                        'show_description': meta['show_description'],
                        'show_name': meta['show_name'],
                        'show_filename_prefix': meta['show_filename_prefix'],
                        'text': ' '.join(tokens),
                        'startTime': (curr_window - 1) * WINDOW_SIZE,
                        'endTime': curr_window * WINDOW_SIZE
                    })

                    tokens = []
                    tokens.append(word['word'])
                    curr_window += 1

    return batch
