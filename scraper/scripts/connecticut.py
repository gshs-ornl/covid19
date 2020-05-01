#!/usr/bin/env python3

import requests
import datetime
import os
import re
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

row_csv = []

# convenience method to turn off huge data for manual review 
def get_raw_data(raw_data):
    return str(raw_data)
    #return 'ALL_DATA_GOES_HERE'

country = 'US'
state = 'Connecticut'
resolution = 'state'
columns = Headers.updated_site

'''
The next four websites can both produce a 'last-modified' property with a non-cached document,
but they also have a 'dateupdated' property in each JSON element. Use that instead.

Each of these websites also have the large possibility of duplicating data from prior times scraped;
this is currently presumed to be accepted.
'''

resolution = 'county'
# generic county data
url = 'https://data.ct.gov/resource/bfnu-rgqt.json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
data = response.json()

# there's also a 'county code' in this data, but this seems to be internally used and is not scraped
for item in data:
    county = item['county']
    cases = int(item['cases'])
    deaths = int(item['deaths'])
    hospitalized = int(item['hospitalization'])
    # Earlier values do not have a 'caserates' value
    try:
        other_value = int(item['caserates'])
        other = 'Rate of Cases per 100,000'
    except KeyError:
        other_value = nan
        other = nan
    updated = datetime.datetime.strptime(item['dateupdated'], "%Y-%m-%dT%H:%M:%S.%f")

    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(data), access_time, nan,
            cases, updated, deaths, nan,
            nan, nan, hospitalized, nan,
            county, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value])

# generic state data
resolution = 'state'
url = 'https://data.ct.gov/resource/rf3k-f8fg.json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
data = response.json()

age_group_keys = ('cases_age0_9', 'cases_age10_19', 'cases_age20_29', 'cases_age30_39', 'cases_age40_49', 
                    'cases_age50_59', 'cases_age60_69', 'cases_age70_79', 'cases_age80_older')
for item in data:
    cases = int(item['cases'])
    deaths = int(item['deaths'])
    hospitalized = int(item['hospitalizations'])
    updated = datetime.datetime.strptime(item['date'], "%Y-%m-%dT%H:%M:%S.%f")
    # early entries do not have reported tests
    try:
        tested = int(item['covid_19_tests_reported'])
    except KeyError:
        tested = nan

    for age_group_key in age_group_keys:
        age_cases = int(item[age_group_key])
        age_range = age_group_key.split('cases_age')[1]
        row_csv.append([
                'state', country, state, nan,
                url, get_raw_data(data), access_time, nan,
                cases, updated, deaths, nan,
                nan, tested, hospitalized, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                resolution, nan, nan, nan,
                nan, nan, nan, nan,
                age_range, age_cases, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                nan, nan])

# gender data
url = 'https://data.ct.gov/resource/qa53-fghg.json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
data = response.json()

for item in data:
    sex = item['gender']
    sex_cases = int(item['cases'])
    updated = datetime.datetime.strptime(item['dateupdated'], "%Y-%m-%dT%H:%M:%S.%f")

    # there will sometimes not be a value for 'Other' gender here
    try:
        other_value = int(item['deaths'])
        other = 'sex_deaths'
    except KeyError:
        other_value = nan
        other = nan
    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(data), access_time, nan,
            nan, updated, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, sex, sex_cases, nan,
            other, other_value])
    
    # There will sometimes be no value here for 'Other' gender
    try:
        other_value = int(item['rate'])
        other = 'Rate of Cases Per 100,000'
    except KeyError:
        other_value = nan
        other = nan
    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(data), access_time, nan,
            nan, updated, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value])

# racial data

url = 'https://data.ct.gov/resource/ypz6-8qyf.json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
data = response.json()

other = 'Rate of Cases Per 100,000'
for item in data:
    age_range = item['agegroups']
    age_cases = int(item['cases'])
    age_deaths = int(item['deaths'])
    other_value = int(item['rate'])
    updated = datetime.datetime.strptime(item['dateupdated'], "%Y-%m-%dT%H:%M:%S.%f")

    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(data), access_time, nan,
            nan, updated, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            age_range, age_cases, age_deaths, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value])

### finished ###

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)