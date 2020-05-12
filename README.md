# COVID-19 

## Introduction

This repository contains scripts, packages, and data to facilitiate web 
scraping and data aggregation related to the COVID-19 pandemic.

## Usage

There is a convenient helper script in the root directory: `dev.sh`. To deploy,
it is recommended to use `./dev.sh -P -d`, which will pull the latest image
from the docker repository and then execute the `docker-compose.yml` with
instructions to build the `api`, `db`, `scraper` and `tidy` images.

## Folders

Inside each folder is another README.md file until it is no longer necessary.
Brief, overview of information relating to what the folder contents, etc. 
and how it pertains to:
    (1) a user
    (2) a developer 
    (3) the curious

### base

This contains the information for building the base image, which is what 
scraper relies upon to run.

### covidb

This is the covidb database container

##### restore from production backup
`./covidb/restore_from_production_db.sh /path/to/covidb_backup_file.tar.gz `


### scraper

The scraper directory contains the actual docker image that will be used
during deploymennt.

## Other Packages and Modules

### cvpy
`cvpy` is a Python module designed to support scraping of state health
department websites. This package is installed during the build of the base
image.

### covidR
`covidR` is an R package designed to support scraping of state health 
department  webpages. While the code for this package does not exist in this 
repository, there is a separate workflow for building the source package. 
It is placed inside base as `covidR.tar.gz` regardless of version number.
When the base image is built, the package is installed.

## Environment
The generic database connection information is stored in the base image, with
specific user and passwords distributed to the built docker containers.

Currently, the `OUTPUT_DIR` is used to store the CSVs produced by the scrapers.
Upon creation of a CSV, the `Slurp()` should be executed to insert the CSV
into the database.

NOTE: The intention is to eventually operate thusly:
The directories are also defined in the base image:
- `OUTPUT_DIR` - the directory where the scrapers output the data as CSVs
- `INPUT_DIR`  - the directory where tidy consolidates and outputs the
                 aggregated directory
- `CLEAN_DIR`  - the directory where the cleaned data is stored
