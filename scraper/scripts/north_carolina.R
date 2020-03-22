#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_north_carolina()
filename <- paste0('../../data/output/north_carolina_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
