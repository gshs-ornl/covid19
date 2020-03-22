#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_puerto_rico()
filename <- paste0('../../data/output/puerto_rico_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
