if (!require(elastic)) {
  install.packages('elastic')
}
if (!require(jsonlite)) {
  install.packages('jsonlite')
}
if (!require(magrittr)) {
  install.packages('magrittr')
}
if (!require(tidyverse)) {
  install.packages('tidyverse')
}

library(magrittr)
library(jsonlite)
library(elastic)
library(tidyverse)
