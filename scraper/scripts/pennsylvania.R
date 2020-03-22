#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_pennsylvania()
filename <- paste0('../../data/output/pennsylvania_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
