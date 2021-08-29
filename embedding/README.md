Quick and crude text embedding for TREC podcast data.

# Requirements:
- A pytorch / colab environment
- A pre-indexed ES instance
- Disk space for output

# Notes
- `embedder` will run every doc in the target ES instance thru embedding and dump the batches out to the output folder
- `slimfast` will read all of the outputs and dump only the ID's and embeddings to new "slim" files. (warning it's not very slim!)
