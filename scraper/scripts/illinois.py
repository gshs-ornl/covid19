#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
date_url = (datetime.datetime.today() - datetime.timedelta(days=1)).strftime('%Y%m%d')
# url = 'http://www.dph.illinois.gov/sites/default/files/COVID19/COVID19CountyResults'+date_url+'.json'
county_cases_url = 'http://www.dph.illinois.gov/sitefiles/COVIDHistoricalTestResults.json?nocache=1'
county_demo_url = 'http://www.dph.illinois.gov/sitefiles/CountyDemos.json?nocache=1'
zipcode_cases_url = 'http://www.dph.illinois.gov/sitefiles/COVIDZip.json?nocache=1'
state = 'Illinois'
columns = Headers.updated_site
row_csv = []

# county-level data (1st url)
url = county_cases_url
resolution = 'county'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

updated_date = raw_data['LastUpdateDate']
for feature in raw_data['characteristics_by_county']['values']:
    county_name = feature['County']
    # This gives the whole state total
    if county_name == 'Illinois':
        resolution = 'state'
        county = nan
    else:
        resolution = 'county'
        county = county_name

    cases = feature['confirmed_cases']
    tested = feature['total_tested']
    negative_tests = feature['negative']
    deaths = feature['deaths']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, updated_date, deaths, nan,
        nan, tested, nan, negative_tests,
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
        nan, nan])

# county-level demographics data (2nd url)
url = county_demo_url
resolution = 'county'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

updated_date = raw_data['LastUpdateDate']
for feature in raw_data['county_demographics']:
    county = feature['County']
    cases = feature['confirmed_cases']
    tested = feature['total_tested']
    for age in feature['demographics']['age']:
        age_range = age['age_group']
        age_cases = age['count']
        other = 'tested'
        other_value = age['tested']
        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, nan, deaths, nan,
            nan, tested, nan, nan,
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
            other, other_value])

    for race in feature['demographics']['race']:
        for text in ['count', 'tested']:
            other = race['description']+'_'+text
            other_value = race[text]

            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, nan, deaths, nan,
                nan, tested, nan, nan,
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

    for gender in feature['demographics']['gender']:
        sex = gender['description']
        sex_counts = gender['count']
        other = sex + '_tested'
        other_value = gender['tested']
        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, nan, deaths, nan,
            nan, tested, nan, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, sex, sex_counts, nan,
            other, other_value])

# zip code-level cases data (3rd url)
url = zipcode_cases_url
resolution = 'zipcode'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

updated_date = raw_data['LastUpdateDate']
for feature in raw_data['zip_values']:
    region = feature['zip']
    cases = feature['confirmed_cases']
    # tested = feature['total_tested']
    for age in feature['demographics']['age']:
        age_range = age['age_group']
        age_cases = age['count']
        # other = 'tested'
        # other_value = age['tested']
        row_csv.append([
            'state', country, state, region,
            url, str(raw_data), access_time, nan,
            cases, nan, nan, nan,
            nan, nan, nan, nan,
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

    for race in feature['demographics']['race']:
        for text in ['count']:
            other = race['description'] + '_' + text
            other_value = race[text]

            row_csv.append([
                'state', country, state, region,
                url, str(raw_data), access_time, nan,
                cases, nan, nan, nan,
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


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
