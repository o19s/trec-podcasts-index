def chunkit(tx, meta):
    return get_chunks(0, tx, meta) + get_chunks(60, tx, meta)

def get_chunks(offset, tx, meta):
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
                # Some results have the same tokens we need to toss them out until we get something new
                if float(word['startTime'][0:-1]) < (((curr_window - 1) * WINDOW_SIZE) + offset):
                    continue

                if float(word['startTime'][0:-1]) < ((curr_window * WINDOW_SIZE) + offset):
                    offset_cleared = True
                    tokens.append(word['word'])

                else:
                    start_time = ((curr_window - 1) * WINDOW_SIZE) + offset

                    batch.append({
                        'lookup': 'spotify:episode:{}_{:g}.0'.format(meta['episode_filename_prefix'], start_time),
                        'episode_description': meta['episode_description'],
                        'episode': meta['episode_filename_prefix'],
                        'episode_name': meta['episode_name'],
                        'show_description': meta['show_description'],
                        'show_name': meta['show_name'],
                        'show_filename_prefix': meta['show_filename_prefix'],
                        'text': ' '.join(tokens),
                        'startTime': start_time,
                        'endTime': (curr_window * WINDOW_SIZE) + offset
                    })

                    tokens = []
                    curr_window += 1

    # Leftover if the offset cleared
    if len(tokens) > 0:
            start_time = ((curr_window - 1) * WINDOW_SIZE) + offset

            batch.append({
                'lookup': 'spotify:episode:{}_{:g}.0'.format(meta['episode_filename_prefix'], start_time),
                'episode_description': meta['episode_description'],
                'episode': meta['episode_filename_prefix'],
                'episode_name': meta['episode_name'],
                'show_description': meta['show_description'],
                'show_name': meta['show_name'],
                'show_filename_prefix': meta['show_filename_prefix'],
                'text': ' '.join(tokens),
                'startTime': start_time,
                'endTime': (curr_window * WINDOW_SIZE) + offset
            })




    return batch


