#!/usr/bin/env python3

import datetime
import requests
import os
import pandas as pd
from numpy import nan
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
state = 'Pennsylvania'
columns = Headers.updated_site
columns.extend(['cases_redacted_lower_bound', 'cases_redacted_upper_bound', 
                'negative_redacted_lower_bound', 'negative_redacted_upper_bound',  
                'presumptive_redacted_lower_bound', 'presumptive_redacted_upper_bound'])
row_csv = []

# county data
resolution = 'county'
url = 'https://services2.arcgis.com/xtuWQvb2YQnp0z3F/ArcGIS/rest/services/DOH_Dashboard_Data/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attributes = feature['attributes']
    county = attributes['County']
    cases = attributes['Positive']
    negative = attributes['Negative']
    deaths = attributes['Deaths']
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        cases, updated, deaths, nan,
        nan, nan, nan, negative,
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
        nan, nan, # custom values after this row
        nan, nan,
        nan, nan,
        nan, nan])

## zip codes
url = 'https://services2.arcgis.com/xtuWQvb2YQnp0z3F/ArcGIS/rest/services/Zip_Code_COVID19_Case_Data/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

resolution = 'zipcode'
REDACTED_LOWER_BOUND = 1
REDACTED_UPPER_BOUND = 4

for feature in raw_data['features']:
    attributes = feature['attributes']
    region = attributes['ZIP_CODE']
    
    # '-1' values indicate a redacted value with 1-4 instances
    cases_redacted_lower_bound = nan
    cases_redacted_upper_bound = nan
    negative_redacted_lower_bound = nan
    negative_redacted_upper_bound = nan
    presumptive_redacted_lower_bound = nan
    presumptive_redacted_upper_bound = nan
    cases = attributes['Positive']
    if cases == -1:
        cases = nan
        cases_redacted_lower_bound = REDACTED_LOWER_BOUND
        cases_redacted_upper_bound = REDACTED_UPPER_BOUND
    negative = attributes['Negative']
    if negative == -1:
        negative = nan
        negative_redacted_lower_bound = REDACTED_LOWER_BOUND
        negative_redacted_upper_bound = REDACTED_UPPER_BOUND
    presumptive = attributes['Probable']
    if presumptive == -1:
        presumptive = nan
        presumptive_redacted_lower_bound = REDACTED_LOWER_BOUND
        presumptive_redacted_upper_bound = REDACTED_UPPER_BOUND
           
    row_csv.append([
        'state', country, state, region,
        url, get_raw_data(raw_data), access_time, nan,
        cases, updated, nan, presumptive,
        nan, nan, nan, negative,
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
        nan, nan, # custom values after this row
        cases_redacted_lower_bound, cases_redacted_upper_bound,
        negative_redacted_lower_bound, negative_redacted_upper_bound,
        presumptive_redacted_lower_bound, presumptive_redacted_upper_bound])


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)