#!/usr/bin/env python3
""" retrieve the scrape functions from covidR and pass them to the generic
    run_script.R script runner which will write the CSVs to disk
"""
import subprocess
from rpy2.robjects import importr

covidR = importr('covidR')
fxns = covidR.get_scraper_functions()
for fxn in fxns:
    subprocess.run(['run_script.R', fxn])
