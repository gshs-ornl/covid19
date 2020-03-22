#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_nebraska()
filename <- paste0('../../data/output/nebraska_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
