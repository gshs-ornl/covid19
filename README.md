# COVID-19 

## Introduction

This repository contains scripts, packages, and data to facilitiate web 
scraping and data aggregation related to the COVID-19 pandemic.

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
