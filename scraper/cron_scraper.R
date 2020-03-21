#!/usr/bin/env Rscript
library(covidR)

alabama <- scrape_alabama()
california <- scrape_california()
colorado <- scrape_colorado()
dc <- scrape_dc()
florida <- scrape_florida()
georgia <- scrape_georgia()
#hawaii <- scrape_hawaii()
#idaho <- scrape_idaho()
louisiana <- scrape_louisiana()
maine <- scrape_maine()
michigan <- scrape_michigan()
minnesota <- scrape_minnesota()
montana <- scrape_montana()
nebraska <- scrape_nebraska()
new_hampshire <- scrape_new_hampshire()
new_jersey <- scrape_new_jersey()
hattiesburg <- scrape_hattiesburg()
dat <- data.table::rbindlist(list(
  alabama,
  california,
  colorado,
  dc,
  florida,
  georgia,
#  hawaii,
  # idaho,
  louisiana,
  maine,
  michigan,
  minnesota,
  montana,
  nebraska,
  new_hampshire,
  new_jersey,
  hattiesburg
), fill = TRUE)

file_name <- paste0('R_', format(Sys.time(), format = '%Y-%m-%d_%M%H'), '.csv')
data.table::fwrite(dat, file = file_name, quote = 'escape', eol = '\n',
                   yaml = TRUE)
