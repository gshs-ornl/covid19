#!/usr/bin/env Rscript
library(covidR)

args <- commandArgs(trailingOnly = TRUE)

stopifnot(len(args) == 1))
wrap_scraper(args[1])
