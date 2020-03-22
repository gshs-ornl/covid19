#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_wisconsin()
filename <- paste0('../../data/output/wisconsin_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
