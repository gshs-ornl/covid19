#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- wrap_scraper(scrape_hopkins_daily_once())
