#!/usr/bin/env python3

import requests
import datetime
import json
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers


country = 'US'
url = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=totalCountyPosFin%20desc&resultOffset=0&resultRecordCount=93'
state_url_cases = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/1/query?f=json&where=lab_status%3D%27Positive%27%20AND%20NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
state_url_negative = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/1/query?f=json&where=lab_status%3D%27Not%20Detected%27%20AND%20NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
state_url_tested = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/1/query?f=json&where=NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
state = 'Nebraska'

columns = Headers.updated_site

row_csv = []

raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
resolution = 'county'

for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['NAME']
    cases = attribute['totalCountyPosFin']
    negative = attribute['totalCountyNotDetFin']
    tested = attribute['totalCountyTestedFin']

    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
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
            nan, nan])


resolution = 'state'
raw_data = requests.get(state_url_cases).json()
access_time = datetime.datetime.utcnow()
cases = raw_data['features'][0]['attributes']['value']

row_csv.append([
            'state', country, state, nan,
            state_url_cases, str(raw_data), access_time, nan,
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
            nan, nan])


raw_data = requests.get(state_url_negative).json()
access_time = datetime.datetime.utcnow()
negative = raw_data['features'][0]['attributes']['value']

row_csv.append([
            'state', country, state, nan,
            state_url_cases, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
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
            nan, nan])


raw_data = requests.get(state_url_tested).json()
access_time = datetime.datetime.utcnow()
tested = raw_data['features'][0]['attributes']['value']

row_csv.append([
            'state', country, state, nan,
            state_url_cases, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
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

# with open('nebraska_state_data.json', 'w') as f:
#    json.dump(raw_data, f)

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv('nebraska_.csv', index=False)
