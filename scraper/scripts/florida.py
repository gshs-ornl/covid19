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
state = 'Florida'
columns = Headers.updated_site
row_csv = []
url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
zipcode_cases_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_Cases_Zips_COVID19/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=COUNTYNAME%20asc&resultOffset=0&resultRecordCount=4000&resultType=standard&cacheHint=true'
state_tot_cases_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22T_positive%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_deaths_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27%20AND%20Died%3D%27Yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_tested_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_Testing/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22T_total%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_negative_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22T_negative%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_agegrp_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_0_4%22%2C%22outStatisticFieldName%22%3A%22C_Age_0_4%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_5_14%22%2C%22outStatisticFieldName%22%3A%22C_Age_5_14%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_15_24%22%2C%22outStatisticFieldName%22%3A%22C_Age_15_24%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_25_34%22%2C%22outStatisticFieldName%22%3A%22C_Age_25_34%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_35_44%22%2C%22outStatisticFieldName%22%3A%22C_Age_35_44%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_45_54%22%2C%22outStatisticFieldName%22%3A%22C_Age_45_54%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_55_64%22%2C%22outStatisticFieldName%22%3A%22C_Age_55_64%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_65_74%22%2C%22outStatisticFieldName%22%3A%22C_Age_65_74%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_75_84%22%2C%22outStatisticFieldName%22%3A%22C_Age_75_84%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_85plus%22%2C%22outStatisticFieldName%22%3A%22C_Age_85plus%22%7D%5D&resultType=standard&cacheHint=true'
state_race_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_RaceWhite%22%2C%22outStatisticFieldName%22%3A%22C_RaceWhite%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_RaceBlack%22%2C%22outStatisticFieldName%22%3A%22C_RaceBlack%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_RaceOther%22%2C%22outStatisticFieldName%22%3A%22C_RaceOther%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_RaceUnknown%22%2C%22outStatisticFieldName%22%3A%22C_RaceUnknown%22%7D%5D&resultType=standard&cacheHint=true'
state_ethnicity_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_HispanicNO%22%2C%22outStatisticFieldName%22%3A%22C_HispanicNO%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_HispanicYES%22%2C%22outStatisticFieldName%22%3A%22C_HispanicYES%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_HispanicUnk%22%2C%22outStatisticFieldName%22%3A%22C_HispanicUnk%22%7D%5D&resultType=standard&cacheHint=true'

# FL residents
state_flres_cases_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_AllResTypes%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_flres_hospitalized_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_HospYes_Res%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_flres_deaths_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_FLResDeaths%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'


resolution = 'county'
county_list = []
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

keys_used = ['County_1','C_FLRes', 'C_NotFLRes', 'C_Hosp_Yes',
             'T_NegRes', 'T_NegNotFLRes', 'TPending',
             'OBJECTID_12_13', 'OBJECTID', 'OBJECTID_1', 'DEPCODE',
             'COUNTY', 'COUNTYNAME', 'DATESTAMP', 'ShapeSTAre',
             'ShapeSTLen', 'OBJECTOD_1', 'State', 'OBJECTID_12',
             'DEPCODE_1', 'COUNTYN', 'Shape__Area', 'Shape__Length']
gender_keys = ['C_Men', 'C_Women', 'C_SexUnkn']
age_keys = ['Age_0_4', 'Age_5_14', 'Age_15_24',
            'Age_25_34', 'Age_35_44', 'Age_45_54',
            'Age_55_64', 'Age_65_74', 'Age_75_84',
            'Age_85plus', 'Age_Unkn']
other_keys = ['C_AgeRange', 'C_AgeMedian']
race_eth_keys = ['C_RaceWhite', 'C_RaceBlack', 'C_RaceOther', 'C_RaceUnknown',
             'C_HispanicYES', 'C_HispanicNO', 'C_HispanicUnk']

keys_used.extend(gender_keys)
keys_used.extend(age_keys)
# Aggregated gender data
state_gender_data = {key: [] for key in gender_keys}

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County_1']
    county_list.append(county)
    if county != 'Unknown':
        key_list = attribute.keys()
        # Get FL Resident and non-resident in FL
        cases = attribute['CasesAll']
        deaths = attribute['Deaths']
        hospitalized = attribute['C_HospYes_Res'] + attribute['C_HospYes_NonRes']
        tested = attribute['T_total']
        negative_tests = attribute['T_negative']
        pending = attribute['TPending']
        monitored = attribute['MonNow']
        no_longer_monitored = attribute['EverMon'] - monitored
        inconclusive = attribute['TInconc']

        for age_key in age_keys:
            age_range = age_key.split('Age_')[1]
            age_tested = attribute[age_key]
            age_cases_key = "C_"+age_key
            age_cases_raw = attribute.get(age_cases_key)
            if age_cases_raw is not None:
                age_cases = age_cases_raw
            else:
                age_cases = nan

            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, updated, deaths, nan,
                nan, tested, hospitalized, negative_tests,
                nan, nan, nan, nan, nan,
                monitored, no_longer_monitored, pending,
                nan, inconclusive, nan,
                nan, nan, nan,
                resolution, nan, nan, nan,
                nan, nan, nan, nan,
                age_range, age_cases, nan, nan,
                nan, age_tested, nan,
                nan, nan,
                nan, nan, nan, nan,
                nan, nan])

        for gender_key in gender_keys:
            sex = gender_key.split('C_')[1]
            sex_counts = attribute[gender_key]
            state_gender_data[gender_key].append(int(sex_counts))
            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, updated, deaths, nan,
                nan, tested, hospitalized, negative_tests,
                nan, nan, nan, nan, nan,
                monitored, no_longer_monitored, pending,
                nan, inconclusive, nan,
                nan, nan, nan,
                resolution, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, sex, sex_counts, nan,
                nan, nan])

        for race_eth_key in race_eth_keys:
            if 'Race' in race_eth_key:
                other = 'race'
                other_value = race_eth_key.replace('C_Race', '')
            elif 'Hispanic' in race_eth_key:
                other = 'ethnicity'
                if race_eth_key == 'C_HispanicYES':
                    other_value = 'Hispanic'
                elif race_eth_key == 'C_HispanicNO':
                    other_value = 'Not_Hispanic'
                elif race_eth_key == 'C_HispanicUnk':
                    other_value = 'Unknown_Hispanic'
            cases = attribute[race_eth_key]
            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
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
                other, other_value])


# Added the aggregated gender data for state-level
resolution = 'state'
for state_gender_data_key in state_gender_data.keys():
    sex = state_gender_data_key.split('C_')[1]
    sex_counts = sum(state_gender_data[state_gender_data_key])
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
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, sex, sex_counts, nan,
        nan, nan])

'''
        for key in key_list:
            if key not in keys_used:
                other = key
                other_value = attribute[key]
                row_csv.append([
                    'state', country, state, nan,
                    url, str(raw_data), access_time, county,
                    cases, updated, deaths, nan,
                    nan, nan, nan, negative_tests,
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
'''

# new cases per day by county
resolution = 'county'
if len(county_list) > 0:
    for county in county_list:
        url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID_19_Cases_by_Day_For_Time_Series/FeatureServer/0/query?where=County+%3D+%27'+county+'%27&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&sqlFormat=standard&f=pjson&token='
        response = requests.get(url)
        access_time = datetime.datetime.utcnow()
        updated = determine_updated_timestep(response)
        raw_data = response.json()

        for feature in raw_data['features']:
            attribute = feature['attributes']
            county = attribute['County']
            update_date = float(attribute['Date'])
            updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))
            other = 'new_cases_per_day'
            other_value = attribute['FREQUENCY']

            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                nan, updated, nan, nan,
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

# zipcode level data
resolution = 'zipcode'
url = zipcode_cases_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attribute = feature['attributes']
    cases = attribute['Cases_1'].replace('<', '')
    region = attribute['ZIP']
    if cases != "SUPPRESSED":
        row_csv.append([
            'state', country, state, region,
            url, str(raw_data), access_time, nan,
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


# State-level data
resolution = 'state'
for url in [state_tot_cases_url, state_tested_url, state_negative_url,
            state_deaths_url]:
    response = requests.get(url)
    access_time = datetime.datetime.utcnow()
    updated = determine_updated_timestep(response)
    raw_data = response.json()
    cases, tested, negative, deaths = nan, nan, nan, nan
    if url == state_tot_cases_url:
        cases = raw_data['features'][0]['attributes']['value']
    elif url == state_tested_url:
        tested = raw_data['features'][0]['attributes']['value']
    elif url == state_negative_url:
        negative = raw_data['features'][0]['attributes']['value']
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, updated, deaths, nan,
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

url = state_agegrp_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
attribute = raw_data['features'][0]['attributes']
age_group_keys = attribute.keys()
for age_group in age_group_keys:
    age_range = age_group
    age_cases = attribute[age_group]
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
        age_range, age_cases, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])


for url in [state_flres_hospitalized_url, state_flres_cases_url,
            state_flres_deaths_url]:
    response = requests.get(url)
    access_time = datetime.datetime.utcnow()
    updated = determine_updated_timestep(response)
    raw_data = response.json()
    other_value = raw_data['features'][0]['attributes']['value']
    if url == state_flres_cases_url:
        other = 'FL_res_cases'
    elif url == state_flres_hospitalized_url:
        other = 'FL_res_hospitalized'
    elif url == state_flres_deaths_url:
        other = 'FL_res_deaths'

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
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value])

url = state_race_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
attribute = raw_data['features'][0]['attributes']
race_keys = attribute.keys()
for race_key in race_keys:
    other = 'race'
    other_value = race_key.replace('C_Race', '')
    cases = attribute[race_key]
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
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
        other, other_value])

url = state_ethnicity_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
attribute = raw_data['features'][0]['attributes']
eth_keys = attribute.keys()
for eth_key in eth_keys:
    other = 'ethnicity'
    if eth_key == 'C_HispanicNO':
        other_value = 'Non-Hispanic'
    elif eth_key == 'C_HispanicYES':
        other_value = 'Hispanic'
    elif eth_key == 'C_HispanicUnk':
        other_value = 'Unknown_or_no_data'
    else:
        other_value = eth_key
    cases = attribute[eth_key]
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
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
        other, other_value])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=Headers.updated_site)
df.to_csv(file_name, index=False)
