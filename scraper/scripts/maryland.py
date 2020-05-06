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
url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MD_COVID19_Case_Counts_by_County/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state_url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MASTER_CaseTracker/FeatureServer/0//query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&sqlFormat=standard&f=pjson&token='
state = 'Maryland'
resolution = 'county'
columns = Headers.updated_site


response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

row_csv = []

# keys_list = ['EOCStatus']

for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['COUNTY']
    cases = attribute['TotalCaseCount']
    #recovered = attribute['COVID19Recovered']
    deaths = attribute['TotalDeathCount']
    '''
    for key in keys_list:
        other = key
        other_value = attribute[key]
    '''
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
            nan, nan])

with open('maryland_county_data.json', 'w') as f:
    json.dump(raw_data, f)
'''
raw_data = requests.get(state_url).json()
access_time = datetime.datetime.utcnow()

age_keys = ["case0to9", "case10to19", "case20to29", "case30to39", "case40to49",
            "case50to59", "case60to69", "case70to79", "case80plus"]
other_keys = ['total_released']

for feature in raw_data['features']:
    attribute = feature['attributes']
    if attribute['Filter'] is not None:
        cases = attribute['TotalCases']
        negative = attribute['NegativeTests']
        hospitalized = attribute['total_hospitalized']
        cases_male = attribute['Male']
        cases_female = attribute['Female']
        deaths = attribute['deaths']

        for age_key in age_keys:
            age_range = age_key.split('case')[1]
            age_cases = attribute[age_key]
            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, updated, deaths, nan,
                nan, nan, hospitalized, negative,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                resolution, nan, cases_male, cases_female,
                nan, nan, nan, nan,
                age_range, age_cases, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                nan, nan])

        for other_key in other_keys:
            other = other_key
            other_value = attribute[other]

            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, updated, deaths, nan,
                nan, nan, hospitalized, negative,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                resolution, nan, cases_male, cases_female,
                nan, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                other, other_value])

with open('maryland_state_data.json', 'w') as f:
    json.dump(raw_data, f)
'''
now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
