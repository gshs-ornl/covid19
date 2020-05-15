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

# convenience method to turn off huge data for manual review - use for HTML and JSON
def get_raw_data(raw_data):
    return str(raw_data)
    #return 'RAW_DATA_REMOVED_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    return dataframe.to_string()
    #return 'RAW_DATA_REMOVED_HERE'

country = 'US'
state = 'Guam'

columns = Headers.updated_site
columns.extend(['race'])
row_csv = []

resolution = 'state'

# generic data
url = 'https://services2.arcgis.com/FPJlJZYRsD8OhCWA/ArcGIS/rest/services/Testing_and_Status_Query/FeatureServer/0/query?where=1%3D1&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

features = raw_data['features']
negative = int(features[0]['attributes']['Count'])
cases = int(features[4]['attributes']['Count'])
deaths = int(features[5]['attributes']['Count'])
recovered = int(features[6]['attributes']['Count'])
presumptive = int(features[8]['attributes']['Count'])

for i in (1, 2, 3):
    lab = features[i]['attributes']['Variable']
    lab_positive = int(features[i]['attributes']['Count'])
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        cases, updated, deaths, presumptive,
        recovered, nan, nan, negative,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        lab, nan, lab_positive, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan,
        nan])

for i in (7, 9):
    other = features[i]['attributes']['Variable']
    other_value = int(features[i]['attributes']['Count'])
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        cases, updated, deaths, presumptive,
        recovered, nan, nan, negative,
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
        other, other_value,
        nan])

# race/ethnicity statistics
url = 'https://services2.arcgis.com/FPJlJZYRsD8OhCWA/arcgis/rest/services/Ethnicity_Query/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&outFields=*&groupByFieldsForStatistics=Race_Ethnicity&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22Cases%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

other = 'race_cases'
for feature in raw_data['features']:
    attributes = feature['attributes']
    race = attributes['Race_Ethnicity']
    other_value = int(attributes['value'])
    row_csv.append([
        'state', country, state, nan,
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
        other, other_value,
        race])

# age group statistics
url = 'https://services2.arcgis.com/FPJlJZYRsD8OhCWA/arcgis/rest/services/Age_Group_Query/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&outFields=*&groupByFieldsForStatistics=Age_Group&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22Cases%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attributes = feature['attributes']
    age_range = attributes['Age_Group']
    age_cases = int(attributes['value'])
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        nan, updated, nan, nan,
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
        nan, nan,
        nan])

# gender statistics
url = 'https://services2.arcgis.com/FPJlJZYRsD8OhCWA/arcgis/rest/services/Sex_Query/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&outFields=*&groupByFieldsForStatistics=Sex&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22Cases%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attributes = feature['attributes']
    sex = attributes['Sex']
    sex_counts = int(attributes['value'])
    row_csv.append([
        'state', country, state, nan,
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
        nan, sex, sex_counts, nan,
        nan, nan,
        nan])

# cases/recovered/deaths over several dates
url = 'https://services2.arcgis.com/FPJlJZYRsD8OhCWA/arcgis/rest/services/Cases_Recovered_Deaths_Query/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&outFields=*&orderByFields=Date%20asc'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
raw_data = response.json()

for feature in raw_data['features']:
    attributes = feature['attributes']
    updated = datetime.datetime.fromtimestamp(attributes['Date'] / 1e3)
    cases = int(attributes['Cases'])
    deaths = int(attributes['Deaths'])
    recovered = int(attributes['Recovered'])
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        cases, updated, deaths, nan,
        recovered, nan, nan, nan,
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
        nan])

# by village
resolution = 'village'

url = 'https://services2.arcgis.com/FPJlJZYRsD8OhCWA/ArcGIS/rest/services/Village_Query/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnExceededLimitFeatures=true&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attributes = feature['attributes']
    try:
        cases = int(attributes['Cases'])
    except TypeError:
        # 0 values are stored as 'null'
        cases = 0
    region = attributes['Village']
    try:
        recovered = int(attributes['Recoveries'])
    except TypeError:
        # 0 values are stored as 'null'
        recovered = 0
    row_csv.append([
        'state', country, state, region,
        url, get_raw_data(raw_data), access_time, nan,
        cases, updated, nan, nan,
        recovered, nan, nan, nan,
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
        nan])

### finished

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)