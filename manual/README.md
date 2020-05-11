# Manual Scraping Instructions

First run the `manual_setup.sh` to create the necessary directories in your
local tmp directory.

## R
`cron_scraper.R` will run all the R scrapers in the `covidR` package and output
a zipped file in the current directory if no arguments are specified, if a
different directory is desired, it can be supplied as an an argument, e.g.
`./cron_scraper.R /home/user/Documents`.

