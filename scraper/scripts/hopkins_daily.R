#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- wrap_scraper(scrape_hopkins_daily())
filename <- paste0('/tmp/output/hopkins_daily_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
