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
if (!require(Hmisc)) {
  install.packages('Hmisc')
}
if (!require(plotly)) {
  install.packages('plotly')
}

library(XML)
library(Hmisc)
library(plotly)
library(magrittr)
library(jsonlite)
library(elastic)
library(tidyverse)
