#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_south_dakota()
filename <- paste0('../../data/output/south_dakota_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
