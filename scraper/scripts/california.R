#!/usr/bin/env Rscript
library(covidR)
library(data.table)

dt <- scrape_california()
filename <- paste0('../../data/output/california_',
                   format(Sys.Date(),format = '%Y%d%m%H%M'), '.csv')
dt[, page := NULL]
fwrite(dt, file = filename)
