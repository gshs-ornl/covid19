#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
url = 'https://services.arcgis.com/vPD5PVLI6sfkZ5E4/ArcGIS/rest/services/IA_COVID19_Cases/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson&token='
url_state = 'https://services.arcgis.com/vPD5PVLI6sfkZ5E4/ArcGIS/rest/services/IACOVID19Cases_Demographics/FeatureServer/0/query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&sqlFormat=standard&f=pjson&token='
state = 'Iowa'
resolution = 'county'
columns = Headers.updated_site
row_csv = []

# County level
response = requests.get(url)
access_time = datetime.datetime.utcnow()
raw_data = response.json()
resolution = 'county'

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['Name']
    cases = attribute['Confirmed']
    recovered = attribute['Recovered']
    updated = attribute['last_updated']
    deaths = attribute['Deaths']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, updated, deaths, nan,
        recovered, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan,  nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])


# State level - Demographics
response = requests.get(url_state)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
resolution = 'state'
age_keys = ['Child_0_17', 'Adult_18_40', 'Middle_Age_41_60',
            'Older_Adult_61_80', 'Elderly_81']
# other_keys = 'NeverHospitalized'

for feature in raw_data['features']:
    attribute = feature['attributes']
    cases = attribute['Total_Cases']
    cases_male = attribute['Male_Cases']
    cases_female = attribute['Female_Cases']
    recovered = attribute['DischRecov']
    hospitalized = attribute['CurrHospitalized']
    deaths = attribute['Deceased']
    tested = attribute['PeopleTested']
    # other = other_keys
    # other_value = attribute[other_keys]

    for key in age_keys:
        age_range = key
        age_cases = attribute[key]

        row_csv.append([
            'state', country, state, nan,
            url_state, str(raw_data), access_time, nan,
            cases, updated, deaths, nan,
            recovered, tested, hospitalized, nan,
            nan, nan, nan, nan, nan,
            nan,  nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, cases_male, cases_female,
            nan, nan, nan, nan,
            age_range, age_cases, nan, nan,
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
