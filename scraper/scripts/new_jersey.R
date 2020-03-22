#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_new_jersey()
filename <- paste0('../../data/output/new_jersey_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
