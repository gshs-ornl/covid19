#!/usr/bin/env Rscript
library(covidR)
library(data.table)
dat <- run_all_scripts()
con <- getDatabaseConnection()
writeTable(dat, con, 'raw', 'scraping', append = TRUE)
dat[, page := NULL]
file_name <- paste0('R_', format(Sys.time(), format = '%Y-%m-%d_%M%H'), '.csv')
data.table::fwrite(dat, file = file_name, quote = 'escape', eol = '\n',
                   yaml = TRUE)
