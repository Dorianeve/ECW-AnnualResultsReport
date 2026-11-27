# libraries required for the ARR pipeline

if(!require(openxlsx)){
  install.packages('openxlsx')
  library(openxlsx)
}

if(!require(Hmisc)){
  install.packages('Hmisc')
  library(Hmisc)
}

# The "core" of the tidyverse, one package at a time and in the same order as library(tidyverse)
# attaches them. The scripts only use these. The `tidyverse` bundle itself is NOT needed, and on
# Linux / WSL it fails to install without many system libraries (fontconfig, freetype, ...).
for (pkg in c("ggplot2", "tibble", "tidyr", "readr", "purrr", "dplyr", "stringr", "forcats", "lubridate")) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

if(!require(stringdist)){
  install.packages('stringdist')
  library(stringdist)
}

if(!require(foreach)){
  install.packages('foreach')
  library(foreach)
}

if(!require(janitor)) {
  install.packages("janitor")
  library(janitor)
}

if(!require(ggplot2))  {
  install.packages("ggplot2")
  library(ggplot2)
}

if(!require(scales))  {
  install.packages("scales")
  library(scales)
}

if(!require(readxl)) {
  install.packages("readxl")
  library(readxl)
}

if(!require(stringr)) {
  install.packages("stringr")
  library(stringr)
}

if(!require(purrr)) {
  install.packages("purrr")
  library(purrr)
}

if(!require(yaml)) {
  install.packages("yaml")
  library(yaml)
}

if(!require(ggplot2)) {
  install.packages(("ggplot2"))
}

if(!require(magrittr)) {
  install.packages(("magrittr"))
}

# used by the optional Airtable sync (scripts/airtable/, functions/airtable_sync.R)
if(!require(httr)) {
  install.packages('httr')
  library(httr)
}

if(!require(jsonlite)) {
  install.packages('jsonlite')
  library(jsonlite)
}
