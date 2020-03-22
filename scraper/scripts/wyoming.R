#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_wyoming()
filename <- paste0('../../data/output/wyoming_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
