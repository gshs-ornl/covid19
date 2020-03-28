#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- wrap_scraper(scrape_tomquisel_once())
filename <- paste0('/tmp/output/tomquisel_once__',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
