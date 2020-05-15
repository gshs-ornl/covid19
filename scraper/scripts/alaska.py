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
state = 'Alaska'
provider = 'state'
# URL with different counties/regions 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=County&orderByFields=County%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22County%22%2C%22outStatisticFieldName%22%3A%22count_result%22%7D%5D&cacheHint=true'
# url = 'https://opendata.arcgis.com/datasets/375f5ee129834fd9833bd92af54cd8bc_0.geojson'
# state_url_age_group = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/AgeGroupPercentTotal/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=AgeGroup%20asc&resultOffset=0&resultRecordCount=2000&cacheHint=true'
# state_url_hospitalized = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=Hospitalized%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22FID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&cacheHint=true'
# state_url_deaths = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Cases_public/FeatureServer/0/query?f=json&where=Deceased%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22FID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&cacheHint=true'
# state_url_tests = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Tests/FeatureServer/0//query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=Date+DESC&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=1&sqlFormat=standard&f=pjson&token='
# region_url_hospitalized = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/COVID_Hospital_Dataset_(prod)/FeatureServer/0//query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&sqlFormat=standard&f=pjson&token='
state_demo_url = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/Demographic_Distribution_of_Confirmed_Cases/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json'
region_tests_url = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/Geographical_Distribution_of_Tests/FeatureServer/0/query?where=1%3D1&outFields=Region,Borough_Census_Area,Commercial_Tests,ASPHL_Tests,Hosp_Fac_Tests,All_Tests,Population,Population_Percent_Tested&outSR=4326&f=json'
region_cases_url = 'https://services1.arcgis.com/WzFsmainVTuD5KML/arcgis/rest/services/Geographical_Distribution_of_Confirmed_Cases/FeatureServer/0/query?where=1%3D1&outFields=Region,Borough_Census_Area,Community,All_Cases,Community_Cases,Secondary_Cases,Travel_Cases,UI_Cases,Hospitalizations,Deaths&outSR=4326&f=json'

columns = Headers.updated_site
row_csv = []

# Demographics
resolution = 'state'
url = state_demo_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

gender_keys = ['Male', 'Female', 'Unknown Sex']
age_group_keys = ['<10 Years', '10-19 Years', '20-29 Years', '30-39 Years',
                  '40-49 Years', '50-59 Years', '60-69 Years', '70-79 Years',
                  '80+ Years', 'Unknown Age']
ethnicity_keys = ['Hispanic', 'Non-Hispanic', 'Unknown Ethnicity']
race_keys = ['White', 'Black', 'AI/AN', 'Asian', 'NHOPI', 'Multiple',
             'Other', 'Unknown Race']
other_keys = ['All_Cases_Percentage', 'Community_Cases', 'Travel_Cases',
              'UI_Cases', 'Hospitalizations', 'Hospitalizations_Percentage',
              'Deaths']

for feature in raw_data['features']:
    sex, sex_counts = nan, nan
    age_range, age_cases, age_deaths, age_hospitalized, age_hospitalized_percent = nan, nan, nan, nan, nan
    other, other_value = nan, nan
    placeholder = ''

    attribute = feature['attributes']
    demo = attribute['Demographic']
    if demo in age_group_keys:
        age_range = demo
        age_cases = attribute['All_Cases']
        age_deaths = attribute['Deaths']
        age_hospitalized = attribute['Hospitalizations']
        age_hospitalized_percent = attribute['Hospitalizations_Percentage']

    elif demo in gender_keys:
        sex = demo
        sex_counts = attribute['All_Cases']

    elif demo in race_keys:
        placeholder = 'race_' + demo

    elif demo in ethnicity_keys:
        placeholder = 'ethnicity_' + demo

    for other_key in other_keys:
        if demo in age_group_keys and (other != ('Deaths' or 'Hospitalizations' or 'Hospitalizations_Percentage')):
            other = placeholder + other_key
            other_value = attribute[other_key]

            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, nan,
                nan, updated, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                resolution, nan, nan, nan,
                nan, nan, nan, nan,
                age_range, age_cases, nan, age_deaths,
                age_hospitalized, nan, nan,
                nan, nan,
                nan, sex, sex_counts, nan,
                other, other_value])


# Testing by county
resolution = 'county'
url = region_tests_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

other_keys = ['Commercial_Tests', 'Hosp_Fac_Tests']

for feature in raw_data['features']:
    attribute = feature['attributes']
    if attribute['Borough_Census_Area'] == 'Total':
        region = attribute['Region']
        tested = attribute['All_Tests']
        state_tests = attribute['ASPHL_Tests']
        for other in other_keys:
            other_value = attribute[other]
            row_csv.append([
                'state', country, state, region,
                url, str(raw_data), access_time, nan,
                nan, updated, nan, nan,
                nan, tested, nan, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                nan, state_tests, nan,
                resolution, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                other, other_value])

# Cases by county
aggregated_county = {}
url = region_cases_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

other_keys = ['Community_Cases', 'Secondary_Cases', 'Travel_Cases']

for feature in raw_data['features']:
    attribute = feature['attributes']
    if attribute['Community'] == 'Grand Total':
        resolution = 'state'
    else:
        if attribute['Community'] == 'Total':
            resolution = 'Census Area'
            region = attribute['Borough_Census_Area']

            region_data = attribute['Region']
            if region_data not in aggregated_county.keys():
                aggregated_county[region_data] = {}
                aggregated_county[region_data]['cases'] = []
                aggregated_county[region_data]['deaths'] = []
                aggregated_county[region_data]['hospitalized'] = []

            aggregated_county[region_data]['cases'].append(
                int(attribute['All_Cases']))
            aggregated_county[region_data]['hospitalized'].append(
                int(attribute['Hospitalizations']))
            aggregated_county[region_data]['deaths'].append(
                int(attribute['Deaths']))
        else:
            resolution = 'city'
            region = attribute['Community']

        cases = attribute['All_Cases']
        hospitalized = attribute['Hospitalizations']
        deaths = attribute['Deaths']

    for other in ['Community_Cases', 'Secondary_Cases', 'Travel_Cases',
                  'UI_Cases']:
        other_value = attribute[other]
        row_csv.append([
            'state', country, state, region,
            url, str(raw_data), access_time, nan,
            cases, updated, deaths, nan,
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
            other, other_value])

# Import aggregated data
resolution = 'county'
for aggregated_county_key in aggregated_county.keys():
    region = aggregated_county_key
    cases = sum(aggregated_county[region]['cases'])
    hospitalized = sum(aggregated_county[region]['hospitalized'])
    deaths = sum(aggregated_county[region]['deaths'])

    row_csv.append([
        'state', country, state, region,
        url, str(raw_data), access_time, nan,
        cases, updated, deaths, nan,
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


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
