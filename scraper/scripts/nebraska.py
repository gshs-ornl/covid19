#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
state = 'Nebraska'
url = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=totalCountyPosFin%20desc&resultOffset=0&resultRecordCount=93'
state_url_cases = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/3/query?f=json&where=lab_status%3D%27Positive%27%20AND%20NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
state_url_tested = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/3/query?f=json&where=NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
state_url_negative = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/3/query?f=json&where=lab_status%3D%27Not%20Detected%27%20AND%20NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
cases_by_day_url = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/1/query?f=json&where=LAB_REPORT_DATE%3E%3Dtimestamp%20%272020-03-07%2023%3A00%3A00%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=LAB_REPORT_DATE%20asc&resultOffset=0&resultRecordCount=5000'
columns = Headers.updated_site
row_csv = []

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
resolution = 'county'

for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['NAME']
    cases = attribute['totalCountyPosFin']
    negative = attribute['totalCountyNotDetFin']
    tested = attribute['totalCountyTestedFin']
    hospitalized = attribute['totalCountyHospitalized']
    deaths = attribute['totalCountyDeathsFin']
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, updated, deaths, nan,
            nan, tested, hospitalized, negative,
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

resolution = 'state'
response = requests.get(state_url_cases)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

tmp_data_tmp = {}
other_lists = ['PositiveThisDate', 'NotDetectedThisDate',
               'InconclusiveThisDate', 'TotalInconclusiveAsOfThisDate',
               'AllTestsThisDate', ]
cases = raw_data['features'][0]['attributes']['value']

row_csv.append([
            'state', country, state, nan,
            state_url_cases, str(raw_data), access_time, nan,
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
            nan, nan])


response = requests.get(state_url_negative)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
negative = raw_data['features'][0]['attributes']['value']

response = requests.get(cases_by_day_url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attribute = feature['attributes']
    update_date = float(attribute['LAB_REPORT_DATE'])
    updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))

    cases = attribute['TotalPositiveAsOfThisDate']
    negative = attribute['TotalNotDetectedAsOfThisDate']
    tested = attribute['AllTestsAsOfThisDate']
    tmp_data_tmp[updated] = []
    for other in other_lists:
        other_value = attribute[other]
        tmp_data_tmp[updated].append([
            'state', country, state, nan,
            cases_by_day_url, str(raw_data), access_time, nan,
            cases, nan, nan, nan,
            nan, tested, nan, negative,
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

recent_date = sorted(list(tmp_data_tmp.keys()))[-1]
for each_list in tmp_data_tmp[recent_date]:
    row_csv.append(each_list)
response = requests.get(state_url_tested)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
tested = raw_data['features'][0]['attributes']['value']

row_csv.append([
            'state', country, state, nan,
            state_url_cases, str(raw_data), access_time, nan,
            nan, updated, nan, nan,
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
            nan, nan])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
