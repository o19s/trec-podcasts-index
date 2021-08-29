Quick and crude text embedding for TREC podcast data.

# Requirements:
- A pytorch / colab environment
- A pre-indexed ES instance
- Disk space for output

# Notes
- `embedder` will run every doc in the target ES instance thru embedding and dump the batches out to the output folder
- `slimfast` will read all of the outputs and dump the embeddings to a single file (warning it's not very slim!)
