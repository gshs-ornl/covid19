#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_new_hampshire()
filename <- paste0('../../data/output/new_hampshire_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
