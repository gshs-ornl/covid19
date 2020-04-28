#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

columns = Headers.updated_site
country = 'US'
state = 'Nebraska'
url = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=totalCountyPosFin%20desc&resultOffset=0&resultRecordCount=93'
state_url_cases = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/3/query?f=json&where=lab_status%3D%27Positive%27%20AND%20NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
state_url_tested = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/3/query?f=json&where=NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
state_url_negative = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/3/query?f=json&where=lab_status%3D%27Not%20Detected%27%20AND%20NE_JURIS%3D%27yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
cases_by_day_url = 'https://gis.ne.gov/Agency/rest/services/COVID19_County_Layer/MapServer/1/query?f=json&where=LAB_REPORT_DATE%3E%3Dtimestamp%20%272020-03-07%2023%3A00%3A00%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=LAB_REPORT_DATE%20asc&resultOffset=0&resultRecordCount=5000'

row_csv = []

resolution = 'county'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

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
            cases, nan, deaths, nan,
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

# with open('nebraska_state_data.json', 'w') as f:
#   json.dump(raw_data, f)

resolution = 'state'

raw_data = requests.get(cases_by_day_url).json()
access_time = datetime.datetime.utcnow()
tmp_data_tmp = {}
other_lists = ['PositiveThisDate', 'NotDetectedThisDate',
               'InconclusiveThisDate', 'TotalInconclusiveAsOfThisDate',
               'AllTestsThisDate', ]

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

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
