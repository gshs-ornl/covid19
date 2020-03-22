#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_colorado()
filename <- paste0('../../data/output/colorado_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
