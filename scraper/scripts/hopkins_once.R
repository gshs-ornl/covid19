#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- wrap_scraper(scrape_hopkins_daily_once())
filename <- paste0('/tmp/output/hopkins_once_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
