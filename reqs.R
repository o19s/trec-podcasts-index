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
if (!require(XML)) {
  install.packages('XML')
}

library(XML)
library(magrittr)
library(jsonlite)
library(elastic)
library(tidyverse)
