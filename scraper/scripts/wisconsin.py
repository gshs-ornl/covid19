#!/usr/bin/env python3

import requests
import datetime
import os
import time
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
state_data_url = 'https://opendata.arcgis.com/datasets/a4741a982aae496486fe928239dec691_3.geojson'
county_data_url = 'https://services1.arcgis.com/ISZ89Z51ft1G16OK/ArcGIS/rest/services/COVID19_WI/FeatureServer/10/query?where=GEO%20%3D%20%27COUNTY%27&outFields=GEO,NAME,LoadDttm,NEGATIVE,POSITIVE,HOSP_YES,HOSP_NO,HOSP_UNK,POS_FEM,POS_MALE,POS_0_9,POS_10_19,POS_20_29,POS_30_39,POS_40_49,POS_50_59,POS_60_69,POS_70_79,POS_80_89,POS_90,DEATHS,DTHS_FEM,DTHS_MALE,DTHS_0_9,DTHS_10_19,DTHS_20_29,DTHS_30_39,DTHS_40_49,DTHS_50_59,DTHS_60_69,DTHS_70_79,DTHS_80_89,DTHS_90,IP_Y_0_9,IP_Y_10_19,IP_Y_20_29,IP_Y_30_39,IP_Y_40_49,IP_Y_50_59,IP_Y_60_69,IP_Y_70_79,IP_Y_80_89,IP_Y_90,IP_N_0_9,IP_N_10_19,IP_N_20_29,IP_N_30_39,IP_N_40_49,IP_N_50_59,IP_N_60_69,IP_N_70_79,IP_N_80_89,IP_N_90,IP_U_0_9,IP_U_10_19,IP_U_20_29,IP_U_30_39,IP_U_40_49,IP_U_50_59,IP_U_60_69,IP_U_70_79,IP_U_80_89,IP_U_90,IC_YES,IC_Y_0_9,IC_Y_10_19,IC_Y_20_29,IC_Y_30_39,IC_Y_40_49,IC_Y_50_59,IC_Y_60_69,IC_Y_70_79,IC_Y_80_89,IC_Y_90,POS_AIAN,POS_ASN,POS_BLK,POS_WHT,POS_MLTOTH,POS_UNK,POS_E_HSP,POS_E_NHSP,POS_E_UNK,DTH_AIAN,DTH_ASN,DTH_BLK,DTH_WHT,DTH_MLTOTH,DTH_UNK,DTH_E_HSP,DTH_E_NHSP,DTH_E_UNK,POS_HC_Y,POS_HC_N,POS_HC_UNK,DTH_NEW,POS_NEW,NEG_NEW,TEST_NEW,GEOID&returnGeometry=false&orderByFields=LoadDttm%20DESC&outSR=&f=json&resultRecordCount=100'
state = 'Wisconsin'
columns = Headers.updated_site
row_csv = []

start_time = time.time()
# state-level
url = state_data_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

resolution = 'state'
feature = raw_data['features'][0]['properties']

age_group_list = ['90+', '80_89', '70_79', '60_69', '50_59', '40_49', '30_39',
             '20_29', '10_19', '0_9']
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
        cases, updated, deaths, nan,
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
            nan, updated, nan, nan,
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
            nan, updated, deaths, nan,
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
            other, other_value])

for ethnicity in race_list:
    other = 'ethnicity'
    other_value = ethnicity
    deaths = feature['DTH_' + race]
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
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
            other, other_value])
state_time = time.time()
print('done with state data', state_time-start_time)

# county-level
tmp_row_csv = []
url = county_data_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
resolution = 'county'

age_group_list_state = ['0_9', '10_19', '20_29', '30_39', '40_49', '50_59',
                        '60_69', '70_79', '80_89', '90']
races = ['AIAN', 'ASN', 'BLK', 'WHT', 'MLTOTH', 'UNK']
others = ['DTH_NEW', 'POS_NEW', 'NEG_NEW', 'TEST_NEW']

for feature in raw_data['features']:
    attribute = feature['attributes']
    if attribute['NAME'] != 'WI':
        update_date = float(attribute['LoadDttm'])
        updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))
        county = attribute['NAME']
        cases = attribute['POSITIVE']
        negative = attribute['NEGATIVE']
        deaths = attribute['DEATHS']
        fips = attribute['GEOID']
        tmp_row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, updated, deaths, nan,
            nan, nan, nan, negative,
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
            nan, nan])

        for gender in gender_list:
            sex = gender
            sex_counts = attribute['POS_' + gender]
            other = 'deaths'
            other_value = attribute['DTHS_' + gender]
            tmp_row_csv.append([
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
                nan, sex, sex_counts, nan,
                other, other_value])

        for age_group in age_group_list_state:
            age_range = age_group
            age_group = age_group.replace('+', '')
            age_cases = attribute['POS_' + age_group]
            age_hospitalized = attribute['IP_Y_' + age_group]
            age_deaths = attribute['DTHS_' + age_group]
            icu = attribute['IC_Y_' + age_group]
            for other_attr in other_dict_age.keys():
                other = other_dict_age.get(other_attr)
                other_value = attribute[other_attr + age_group]
                tmp_row_csv.append([
                    'state', country, state, nan,
                    url, str(raw_data), access_time, county,
                    nan, updated, nan, nan,
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

        for race in race_list:
            other = 'race'
            other_value = race
            cases = attribute['POS_' + race]
            deaths = attribute['DTH_' + race]
            tmp_row_csv.append([
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
                other, other_value])

        for ethnicity in race_list:
            other = 'ethnicity'
            other_value = ethnicity
            deaths = attribute['DTH_' + race]
            tmp_row_csv.append([
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
                other, other_value])
print('done county level data', time.time()-state_time)

county_df = pd.DataFrame(tmp_row_csv, columns=columns).sort_values(
    'updated', ascending=False)
county_df['updated'] = pd.to_datetime(county_df['updated'])

date_list = sorted(list(county_df.groupby('updated').groups.keys()))
recent_date = date_list[-1].to_pydatetime().strftime('%Y-%m-%d')
county_df['updated'] = county_df['updated'].dt.strftime('%Y-%m-%d')
county_df = county_df[county_df['updated'] == recent_date].sort_values('county')
dict_info_county = {'provider': 'state', 'country': country, "url": url,
                    "state": state, "resolution": "county",
                    "page": str(raw_data), "access_time": access_time,
                    "updated": updated}

# county_df = fill_in_df(county_df, dict_info_county, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

dfs = pd.concat([pd.DataFrame(row_csv, columns=columns), county_df])
dfs.to_csv(file_name, index=False)
