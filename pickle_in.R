library("reticulate")

use_virtualenv("venv/bin/python")
py_config()
source_python("pickle_in.py")

pickle_data <- read_pickle_file("embedding/cache/angles-10.pickle")
