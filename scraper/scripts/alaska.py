#!/usr/bin/env python3

import requests
import datetime
import json
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers


country = 'US'
# URL with different counties/regions 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=County&orderByFields=County%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22County%22%2C%22outStatisticFieldName%22%3A%22count_result%22%7D%5D&cacheHint=true'
url = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=Region&orderByFields=Region%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22County%22%2C%22outStatisticFieldName%22%3A%22count_result%22%7D%5D&cacheHint=true'

state_url_age_group = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/AgeGroupPercentTotal/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=AgeGroup%20asc&resultOffset=0&resultRecordCount=2000&cacheHint=true'
state_url_hospitalized = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=Hospitalized%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22FID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&cacheHint=true'
state_url_deaths = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=Deceased%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22FID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&cacheHint=true'
state = 'Alaska'

columns = Headers.updated_site


raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

row_csv = []


for feature in raw_data['features']:
    resolution = 'county'
    attribute = feature['attributes']
    county = attribute['Region']
    cases = attribute['count_result']
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
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

resolution = 'state'
raw_data = requests.get(state_url_age_group).json()
access_time = datetime.datetime.utcnow()
for feature in raw_data['features']:
    attribute = feature['attributes']
    cases = attribute['CaseTotals']
    age_range = attribute['AgeGroup']
    age_cases = attribute['CountCases']

    row_csv.append([
                'state', country, state, nan,
                state_url_age_group, str(raw_data), access_time, nan,
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


raw_data = requests.get(state_url_hospitalized).json()
access_time = datetime.datetime.utcnow()
hospitalized = raw_data['features'][0]['attributes']['value']

row_csv.append([
            'state', country, state, nan,
            state_url_hospitalized, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
            nan, nan, hospitalized, nan,
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


raw_data = requests.get(state_url_deaths).json()
access_time = datetime.datetime.utcnow()
deaths = raw_data['features'][0]['attributes']['value']

row_csv.append([
            'state', country, state, nan,
            state_url_deaths, str(raw_data), access_time, nan,
            nan, nan, deaths, nan,
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


'''
with open('alaska_state_data.json', 'w') as f:
    json.dump(raw_data, f)
'''
df = pd.DataFrame(row_csv, columns=columns)
df.to_csv('alaska_.csv', index=False)
