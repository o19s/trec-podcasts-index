Quick and crude text embedding for TREC podcast data.

# Requirements:
- A pytorch / colab environment
- A pre-indexed ES instance
- Disk space for output

# Notes
- `text_embedder` will run every doc in the target ES instance thru embedding and dump the batches out to the output folder.  This script takes around 6h to process 3.7M documents so it stores all output out in large pickles for quick access in case needed in the future
- `desc_embedder` takes care of doing embeddings for each episode.  This process runs much faster so we only store out the id's and embeds from the first run on this one.
- `slimfast` will read all of the outputs and dump the embeddings to a single file (warning it's not very slim!)
