#!/usr/bin/env Rscript
library(covidR)
library(data.table)

fxn <- 'scrape_alabama()'
dt <- wrap_scraper(fxn)
