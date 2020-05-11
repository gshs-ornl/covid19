#!/usr/bin/env Rscript
options(repos = c(CRAN = "https://cloud.r-project.org/"))
Sys.setenv(LANG="en_US.UTF-8")
Sys.setenv(LC_ALL="en_US.UTF-8")
install.packages(c('docopt', 'Rpostgres', 'data.table', 'magrittr', 'leaflet',
                   'tidyverse', 'rvest', 'sp', 'sf', 'stringr', 'jsonlite',
                   'rebus', 'lubridate', 'anytime', 'snakecase', 'remotes',
                   'readxl', 'zip', 'rgdal', 'tidycensus', 'stringr', 
                   'googlesheets4', 'bit64'), repos = "https://cloud.r-project.org")
