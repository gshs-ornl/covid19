#!/usr/bin/env Rscript
library(covidR)

# uncomment below and replace with your custom directories to test
# input_dir = '/mnt/forbin/dev/'
# output_dir = '/home/sempervent/Documents/covid19data'
# output_files <- curate_all(input_dir, output_dir)
# comment out below if the above is uncommented for local testing
output_files <- curate_all()
message(gettextf(
  'Created output files: %s', paste0(output_files, collapse = ', ')))
