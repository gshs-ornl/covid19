#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
county_url = 'https://services8.arcgis.com/rGGrs6HCnw87OFOT/arcgis/rest/services/CountyCases/FeatureServer/0/query?f=json&where=(CV_PositiveCases%20%3E%200)%20AND%20(CV_PositiveCases%3E0)&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=CNTY_NAME%20asc&resultOffset=0&resultRecordCount=39&resultType=standard&cacheHint=true'

state = 'Washington'
columns = Headers.updated_site
row_csv = []

# county-state data
url = county_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
resolution = 'county'

state_cases = None
state_deaths = None
state_updated = None

other_attributes = ['CV_Cases_Today', 'CV_Deaths_Today', 'CV_Comment']

for feature in raw_data['features']:
    attribute = feature['attributes']
    update_date = float(attribute['CV_Updated'])
    updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))

    county = attribute['CNTY_NAME']
    cases = attribute['CV_PositiveCases']
    deaths = attribute['CV_Deaths']

    if state_cases is None:
        state_cases = attribute['CV_State_Cases']
        if state_updated is None:
            state_updated = updated
    if state_deaths is None:
        state_deaths = attribute['CV_State_Deaths']
        if state_updated is None:
            state_updated = updated

    for other_attribute in other_attributes:
        if other_attribute == 'CV_Comment':
            interested_txt = 'Phase 1 reopening beginning'
            reopen_date = attribute[other_attribute]
            if interested_txt in reopen_date:
                other_value = reopen_date.split(interested_txt)[1]
                other = interested_txt
            else:
                other, other_value = nan, nan
        else:
            other = other_attribute
            other_value = attribute[other_attribute]

        row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, updated, deaths, nan,
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

# Added the state data here
resolution = 'state'
cases = state_cases
deaths = state_deaths
updated = state_updated
row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, updated, deaths, nan,
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
        nan, nan])


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
