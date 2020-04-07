#!/usr/bin/env python3

import requests
import datetime
import json
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers


country = 'US'
state = 'Alaska'
provider = 'state'
# URL with different counties/regions 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=County&orderByFields=County%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22County%22%2C%22outStatisticFieldName%22%3A%22count_result%22%7D%5D&cacheHint=true'
url = 'https://opendata.arcgis.com/datasets/375f5ee129834fd9833bd92af54cd8bc_0.geojson'
state_url_age_group = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/AgeGroupPercentTotal/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=AgeGroup%20asc&resultOffset=0&resultRecordCount=2000&cacheHint=true'
state_url_hospitalized = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=Hospitalized%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22FID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&cacheHint=true'
state_url_deaths = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=Deceased%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22FID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&cacheHint=true'


columns = Headers.updated_site
row_csv = []

raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

with open('alaska_state_data.json', 'w') as f:
    json.dump(raw_data, f)

resolution = 'county'
dict_info = {'provider': provider,'country': country, "url": url,
             "state": state, "resolution": resolution,
            "page": raw_data, "access_time": access_time}

def fill_in_ak_df(df_list, dict_info, columns):
    ak_df = []
    for each_df in df_list:
        each_df['provider'] = dict_info['provider']
        each_df['country'] = dict_info['country']
        each_df['state'] = dict_info['state']
        each_df['resolution'] = dict_info['resolution']
        each_df['url'] = dict_info['url']
        each_df['page'] = str(dict_info['page'])
        each_df['access_time'] = dict_info['access_time']
        df_columns = list(each_df.columns)
        for column in columns:
            if column not in df_columns:
                each_df[column] = nan
            else:
                pass
        ak_df.append(each_df.reindex(columns=columns))
    return pd.concat(ak_df)

row_csv_raw = []
for feature in raw_data['features']:
    attribute = feature['properties']

    county = attribute['Region']
    hospitalized = attribute['Hospitalized']
    sex = attribute['Sex']
    age_range = attribute['AgeGroup']
    count = 1
    row_csv_raw.append([county, sex, age_range, count, hospitalized])

df = pd.DataFrame(row_csv_raw, columns=['county', 'sex', 'age_range',
                                        'count', 'hospitalized'])

gender_cases = df.groupby(
    ['county','sex']).count().reset_index().drop(
    ['hospitalized', 'age_range'], axis=1).rename(columns={'count': 'sex_counts'})

age_cases = df.groupby(
    ['county', 'age_range']).count().reset_index().drop(
    'hospitalized', axis=1).rename(columns={'count': 'age_cases'})

county_cases = df.groupby(['county']).count().reset_index().drop(
    ['sex', 'age_range', 'hospitalized'], axis=1).rename(
    columns={'count': 'cases'})

hospitalized_df = df[df['hospitalized'] == 'Y'].groupby(
    ['county']).count().reset_index().drop(
    ['count', 'sex', 'age_range'],axis=1)

df_list = [age_cases, county_cases, hospitalized_df]
county_level_df = fill_in_ak_df(df_list, dict_info, columns)

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

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
file_name = state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
all_df = pd.concat([df, county_level_df])
all_df.to_csv(file_name, index=False)
