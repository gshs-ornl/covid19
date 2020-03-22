#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_west_virginia()
filename <- paste0('../../data/output/west_virginia_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
