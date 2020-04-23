#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state_tot_cases_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_deaths_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27%20AND%20Died%3D%27Yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_tested_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_Testing/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22T_total%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_negative_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22T_negative%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_agegrp_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_0_4%22%2C%22outStatisticFieldName%22%3A%22C_Age_0_4%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_5_14%22%2C%22outStatisticFieldName%22%3A%22C_Age_5_14%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_15_24%22%2C%22outStatisticFieldName%22%3A%22C_Age_15_24%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_25_34%22%2C%22outStatisticFieldName%22%3A%22C_Age_25_34%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_35_44%22%2C%22outStatisticFieldName%22%3A%22C_Age_35_44%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_45_54%22%2C%22outStatisticFieldName%22%3A%22C_Age_45_54%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_55_64%22%2C%22outStatisticFieldName%22%3A%22C_Age_55_64%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_65_74%22%2C%22outStatisticFieldName%22%3A%22C_Age_65_74%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_75_84%22%2C%22outStatisticFieldName%22%3A%22C_Age_75_84%22%7D%2C%7B%22statisticType%22%3A%22sum%22%2C%22onStatisticField%22%3A%22C_Age_85plus%22%2C%22outStatisticFieldName%22%3A%22C_Age_85plus%22%7D%5D&resultType=standard&cacheHint=true'

# FL residents
state_flres_cases_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_flres_hospitalized_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27%20AND%20Hospitalized%3D%27YES%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_flres_deaths_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27%20AND%20Died%3D%27Yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'


state = 'Florida'
resolution = 'county'
columns = Headers.updated_site


raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

row_csv = []
keys_used = ['County_1','C_FLRes', 'C_NotFLRes', 'C_Hosp_Yes',
             'T_NegRes', 'T_NegNotFLRes', 'TPending',
             'OBJECTID_12_13', 'OBJECTID', 'OBJECTID_1', 'DEPCODE',
             'COUNTY', 'COUNTYNAME', 'DATESTAMP', 'ShapeSTAre',
             'ShapeSTLen', 'OBJECTOD_1', 'State', 'OBJECTID_12',
             'DEPCODE_1', 'COUNTYN', 'Shape__Area', 'Shape__Length']
gender_keys = ['C_Men', 'C_Women']
age_keys = ['Age_0_4', 'Age_5_14', 'Age_15_24',
            'Age_25_34', 'Age_35_44', 'Age_45_54',
            'Age_55_64', 'Age_65_74', 'Age_75_84',
            'Age_85plus', 'Age_Unkn']

keys_used.extend(gender_keys)
keys_used.extend(age_keys)

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County_1']
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
                cases, nan, deaths, nan,
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

            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, nan, deaths, nan,
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
        '''
        for key in key_list:
            if key not in keys_used:
                other = key
                other_value = attribute[key]
                row_csv.append([
                    'state', country, state, nan,
                    url, str(raw_data), access_time, county,
                    cases, nan, deaths, nan,
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

# State-level data
resolution = 'state'
for url in [state_tot_cases_url, state_tested_url, state_negative_url,
            state_deaths_url]:
    raw_data = requests.get(url).json()
    access_time = datetime.datetime.utcnow()
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
        cases, nan, deaths, nan,
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
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
attribute = raw_data['features'][0]['attributes']
age_group_keys = attribute.keys()
for age_group in age_group_keys:
    age_range = age_group
    age_cases = attribute[age_group]
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


# FL residents
state_flres_cases_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_flres_hospitalized_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27%20AND%20Hospitalized%3D%27YES%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_flres_deaths_url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Case_Line_Data/FeatureServer/0/query?f=json&where=Jurisdiction%3C%3E%27Non-FL%20resident%27%20AND%20Died%3D%27Yes%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'

for url in [state_flres_cases_url, state_flres_hospitalized_url,
            state_flres_deaths_url]:
    raw_data = requests.get(url).json()
    access_time = datetime.datetime.utcnow()
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

# with open('florida_data.json', 'w') as f:
#     json.dump(raw_data, f)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=Headers.updated_site)
df.to_csv(file_name, index=False)
