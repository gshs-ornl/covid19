#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
state_data_url = 'https://opendata.arcgis.com/datasets/a4741a982aae496486fe928239dec691_3.geojson'
county_data_url = 'https://services1.arcgis.com/ISZ89Z51ft1G16OK/ArcGIS/rest/services/COVID19_WI/FeatureServer/5/query?where=1%3D1&outFields=NAME,POSITIVE,NEGATIVE,DEATHS,DATE,OBJECTID,GEOID&returnGeometry=false&orderByFields=DATE%20DESC&outSR=&f=json'
state = 'Wisconsin'
columns = Headers.updated_site
row_csv = []


def fill_in_df(df_list, dict_info, columns):
    if isinstance(df_list, list):
        all_df = []
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
            all_df.append(each_df.reindex(columns=columns))
        final_df = pd.concat(all_df)
    else:
        df_list['provider'] = dict_info['provider']
        df_list['country'] = dict_info['country']
        df_list['state'] = dict_info['state']
        df_list['resolution'] = dict_info['resolution']
        df_list['url'] = dict_info['url']
        df_list['page'] = str(dict_info['page'])
        df_list['access_time'] = dict_info['access_time']
        df_columns = list(df_list.columns)
        for column in columns:
            if column not in df_columns:
                df_list[column] = nan
            else:
                pass
        final_df = df_list.reindex(columns=columns)
    return final_df


# state-level
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


# county-level
tmp_row_csv = []
url = county_data_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
resolution = 'county'

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['NAME']
    cases = attribute['POSITIVE']
    negative = attribute['NEGATIVE']
    fips = attribute['GEOID']
    update_date = float(attribute['DATE'])
    updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))
    tmp_row_csv.append([county, cases, negative, fips, updated])

county_df = pd.DataFrame(tmp_row_csv, columns=[
    'county', 'cases', 'negative', 'fips', 'updated']).sort_values(
    'updated', ascending=False)
county_df['updated'] = pd.to_datetime(county_df['updated'])

date_list = sorted(list(county_df.groupby('updated').groups.keys()))
recent_date = date_list[-1].to_pydatetime().strftime('%Y-%m-%d')
county_df['updated'] = county_df['updated'].dt.strftime('%Y-%m-%d')
county_df = county_df[county_df['updated'] == recent_date].sort_values('county')
dict_info_county = {'provider': 'state', 'country': country, "url": url,
                    "state": state, "resolution": "county",
                    "page": str(raw_data), "access_time": access_time}

county_df = fill_in_df(county_df, dict_info_county, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

dfs = pd.concat([pd.DataFrame(row_csv, columns=columns), county_df])
dfs.to_csv(file_name, index=False)
