#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
county_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/MapServer/0/query?where=1%3D1&text=&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=*&returnGeometry=false&returnTrueCurves=false&maxAllowableOffset=&geometryPrecision=&outSR=&having=&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&historicMoment=&returnDistinctValues=false&resultOffset=&resultRecordCount=&queryByDistance=&returnExtentOnly=false&datumTransformation=&parameterValues=&rangeValues=&quantizationParameters=&f=pjson'
state_death_gender_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=Deceased%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=Sex&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state_death_age_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=Deceased%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=AgeGroup&orderByFields=AgeGroup%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state_cases_gender_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=Sex&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state_cases_age_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=AgeGroup%3C%3E%27Unconfirmed%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=AgeGroup&orderByFields=AgeGroup%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state = 'Kentucky'
columns = Headers.updated_site
row_csv = []

# County-level data
url = county_url
resolution = 'county'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
count_deaths = []
count_cases = []

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County']
    fips = attribute['FIPS']
    icu = attribute['ICU']
    hospitalized = attribute['Hospitalized']
    deaths = attribute['Deceased']
    cases = attribute['Confirmed']
    count_deaths.append(int(deaths))
    count_cases.append(int(cases))

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, nan, deaths, nan,
        nan, nan, hospitalized, nan,
        nan, nan, nan, nan, fips,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, icu, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])

# Aggregated data
resolution = 'state'
row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        sum(count_cases), nan, sum(count_deaths), nan,
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

# State-level data - genders deaths
url = state_death_gender_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

for feature in raw_data['features']:
    attribute = feature['attributes']
    deaths = attribute['value']
    sex = attribute['Sex']
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
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
        nan, sex, nan, nan,
        nan, nan])

# State-level data - age groups deaths
url = state_death_age_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

for feature in raw_data['features']:
    attribute = feature['attributes']
    age_range = attribute['AgeGroup']
    age_deaths = attribute['value']
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            age_range, nan, nan, age_deaths,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            nan, nan])

# State-level data - genders cases
url = state_cases_gender_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

for feature in raw_data['features']:
    attribute = feature['attributes']
    sex = attribute['Sex']
    sex_counts = attribute['value']

    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
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
            nan, nan])

# State-level data - age groups cases
url = state_cases_age_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

for feature in raw_data['features']:
    attribute = feature['attributes']
    age_range = attribute['AgeGroup']
    age_cases = attribute['value']
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
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


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=Headers.updated_site)
df.to_csv(file_name, index=False)
