#!/usr/bin/env python3

import datetime
import requests
import os
import glob
import shutil
import pandas as pd
import zipfile
from io import BytesIO
from numpy import nan
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

# convenience method to turn off huge data for manual review - use for HTML/JSON
def get_raw_data(html_text):
    return str(html_text)
    #return 'RAW_DATA_REMOVED_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    return dataframe.to_string()
    #return 'RAW_DATA_REMOVED_HERE'

country = 'US'
state = 'Hawaii'
columns = Headers.updated_site
columns.extend(['cases_lower_bound', 'cases_upper_bound'])
row_csv = []

## zip codes
url = 'https://services.arcgis.com/HQ0xoN0EzDPBOEci/ArcGIS/rest/services/covid_web_map/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

resolution = 'zipcode'

for feature in raw_data['features']:
    attributes = feature['attributes']
    region = attributes['ZCTA5CE10']
    casestr = (attributes['case_gro_1'])
    if '–' in casestr:
        casearr = casestr.split('–')
        cases_lower_bound = casearr[0]
        cases_upper_bound = casearr[1]
        row_csv.append([
            'state', country, state, region,
            url, get_raw_data(raw_data), access_time, nan,
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
            nan, nan,
            cases_lower_bound, cases_upper_bound])
    else:
        cases = casestr
        row_csv.append([
            'state', country, state, region,
            url, get_raw_data(raw_data), access_time, nan,
            cases, updated, nan, nan,
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
            nan, nan,
            nan, nan])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)