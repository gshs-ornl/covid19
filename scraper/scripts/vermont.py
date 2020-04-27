#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
state = 'Vermont'
state_race_url = """https://services1.arcgis.com/BkFxaEFNwHqX3tAw/arcgis/rest/services/T_VCGI_daily_clean/FeatureServer/0/query?f=json&where=race NOT IN('Unknown')&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=race&orderByFields=race desc&outStatistics=[{"statisticType"%3A"count"%2C"onStatisticField"%3A"OBJECTID"%2C"outStatisticFieldName"%3A"value"}]&resultType=standard&cacheHint=true"""
state_eth_url = """https://services1.arcgis.com/BkFxaEFNwHqX3tAw/arcgis/rest/services/T_VCGI_daily_clean/FeatureServer/0/query?f=json&where=ethnicity NOT IN('Unknown')&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=ethnicity&outStatistics=[{"statisticType"%3A"count"%2C"onStatisticField"%3A"OBJECTID"%2C"outStatisticFieldName"%3A"value"}]&resultType=standard&cacheHint=true"""
state_gender_url = """https://services1.arcgis.com/BkFxaEFNwHqX3tAw/arcgis/rest/services/T_VCGI_daily_clean/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=sex&outStatistics=[{"statisticType"%3A"count"%2C"onStatisticField"%3A"OBJECTID"%2C"outStatisticFieldName"%3A"value"}]&resultType=standard&cacheHint=true"""
state_agegrp_url = """https://services1.arcgis.com/BkFxaEFNwHqX3tAw/arcgis/rest/services/T_VCGI_daily_clean/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=age_group&outStatistics=[{"statisticType"%3A"count"%2C"onStatisticField"%3A"OBJECTID"%2C"outStatisticFieldName"%3A"value"}]&resultType=standard&cacheHint=true"""
state_info_url = 'https://services1.arcgis.com/BkFxaEFNwHqX3tAw/arcgis/rest/services/county_summary/FeatureServer/0//query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=date+DESC&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=1&sqlFormat=standard&f=pjson&token='
# county-level data URL
county_url = 'https://services1.arcgis.com/BkFxaEFNwHqX3tAw/arcgis/rest/services/VT_Counties_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Cases%20desc&resultOffset=0&resultType=standard&cacheHint=true'
columns = Headers.updated_site
row_csv = []

# State-level data
resolution = 'state'

# State-level data: race and ethnicity
for url in [state_race_url, state_eth_url]:
    raw_data = requests.get(url).json()
    access_time = datetime.datetime.utcnow()
    if url == 'state_race_url':
        placeholder = 'cases_race_'
    else:
        placeholder = 'cases_eth_'
    for feature in raw_data['features']:
        attribute = feature['attributes']
        other_value_key = 'value'
        key_list = list(feature['attributes'].keys())
        key_list.remove(other_value_key)
        other = placeholder + attribute[key_list[0]]
        other_value = attribute[other_value_key]
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
            nan, nan, nan, nan,
            other, other_value])

# State-level data: genders and age groups
for url in [state_gender_url, state_agegrp_url]:
    raw_data = requests.get(url).json()
    access_time = datetime.datetime.utcnow()
    for feature in raw_data['features']:
        attribute = feature['attributes']
        if url == state_gender_url:
            sex = attribute['sex']
            sex_counts = attribute['value']
            age_range, age_cases = nan, nan
        elif url == state_agegrp_url:
            age_range = attribute['age_group'].replace('-', '_')
            age_cases = attribute['value']
            sex, sex_counts = nan, nan
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
            nan, sex, sex_counts, nan,
            nan, nan])

url = state_info_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
attribute = raw_data['features'][0]['attributes']
update_date = float(attribute['date'])
updated = str(datetime.datetime.fromtimestamp(update_date/1000.0))
cases = attribute['cumulative_positives']
tested = attribute['total_tests']
deaths = attribute['total_deaths']
hospitalized = attribute['current_hospitalizations']
monitored = attribute['people_monitored']
no_longer_monitored = attribute['completed_monitoring']
other_keys = ['daily_deaths', 'hosp_pui', 'positive_cases']
for other_key in other_keys:
    other_value = attribute[other_key]
    if other_key == 'hosp_pui':
        other = 'hospitalized under investigation.'
    else:
        other = other_key
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, updated, deaths, nan,
        nan, tested, hospitalized, nan,
        nan, nan, nan, nan, nan,
        monitored, no_longer_monitored, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value])

# County-level data
resolution = 'county'
url = county_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['CntyLabel']
    if county != 'Pending Validation':
        fips = attribute['CNTYGEOID']
        cases = attribute['Cases']
        deaths = attribute['Deaths']
        update_date = float(attribute['DateUpd'])
        updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))
        other = 'new_cases'
        other_value = attribute[other]

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, updated, deaths, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, fips,
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

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
