#!/usr/bin/env python3
""" here is the setup file for cvr, the COVID-19 web scraping implementation
"""
import glob
from distutils.core import setup

data_files = glob.glob('*.csv')

setup(
    name='scraper',
    version='0.1.0',
    packages=['cvr'],
    data_files=data_files,
    url='',
    license='GPL 3',
    author='Joshua N. Grant',
    author_email="grantjn@ornl.gov",
    description="COVID-19 Web Scraping scripts, modules, and package"
)
