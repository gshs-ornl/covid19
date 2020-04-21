#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
state_data_url = 'https://opendata.arcgis.com/datasets/a4741a982aae496486fe928239dec691_3.geojson'
state = 'Wisconsin'
columns = Headers.updated_site
row_csv = []

# state level
url = state_data_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
resolution = 'state'
feature = raw_data['features'][0]['properties']

age_group_list = ['90+', '80_89', '70_79', '60_69', '50_59', '40_49', '30_39',
             '20_29', '10_19', '0_10']
gender_list = ['FEM', 'MALE']
race_list = ['AIAN', 'ASN', 'BLK', 'WHT', 'UNK', 'MLTOTH']
ethnicity_list = ['E_NHSP', 'E_HSP', 'E_UNK']
pos = sum([int(feature['POS_HC_UNK']), int(feature['POS_HC_N']),
               int(feature['POS_HC_Y'])])
other_list = [pos,  'HOSP_UNK', 'HOSP_NO']
other_name = ['people with healthcare', 'Unknown hospitalized',
              'Not hospitalized']
other_dict_age = {'IP_N_': "not hospitalized", # 'IC_Y_': 'ICU',
                  "IP_U_": "in patient unknown"}


cases = feature['POSITIVE']
negative = feature['NEGATIVE']
deaths = feature['DEATHS']
hospitalized = feature['HOSP_YES']
icu = feature['IC_YES']
for other_idx in range(0, len(other_name)):
    other = other_name[other_idx]
    if isinstance(other_list[other_idx], int):
        other_value = other_list[other_idx]
    else:
        other_value = feature[other_list[other_idx]]

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, nan, deaths, nan,
        nan, nan, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, icu, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value])

for age_group in age_group_list:
    age_range = age_group
    age_group = age_group.replace('+', '')
    age_cases = feature['POS_' + age_group]
    age_hospitalized = feature['IP_Y_' + age_group]
    age_deaths = feature['DTHS_' + age_group]
    icu = feature['IC_Y_' + age_group]
    for other_attr in other_dict_age.keys():
        other = other_dict_age.get(other_attr)
        other_value = feature[other_attr + age_group]

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, icu, nan, nan,
            nan, nan, nan, nan,
            age_range, age_cases, nan, age_deaths,
            age_hospitalized, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value])

for gender in gender_list:
    sex = gender
    sex_counts = feature['POS_' + gender]
    deaths = feature['DTHS_' + gender]
    # other = 'deaths'
    # other_value = feature['DTHS_' + gender]
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
            nan, sex, sex_counts, nan,
            nan, nan])

for race in race_list:
    other = 'race'
    other_value = race
    cases = feature['POS_' + race]
    deaths = feature['DTH_' + race]
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            cases, nan, deaths, nan,
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

for ethnicity in race_list:
    other = 'ethnicity'
    other_value = ethnicity
    deaths = feature['DTH_' + race]
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            cases, nan, deaths, nan,
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
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
