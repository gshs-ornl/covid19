#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
state = 'Illinois'
date_url = (datetime.datetime.today() - datetime.timedelta(days=1)).strftime('%Y%m%d')
date_url_xlsx = (datetime.datetime.today()).strftime('%Y-%m-%d')
# url = 'http://www.dph.illinois.gov/sites/default/files/COVID19/COVID19CountyResults'+date_url+'.json'
county_cases_url = 'http://www.dph.illinois.gov/sitefiles/COVIDHistoricalTestResults.json?nocache=1'
county_demo_url = 'http://www.dph.illinois.gov/sitefiles/CountyDemos.json?nocache=1'
zipcode_cases_url = 'http://www.dph.illinois.gov/sitefiles/COVIDZip.json?nocache=1'
race_eth_url = 'https://www.chicago.gov/content/dam/city/sites/covid/reports/'+\
               date_url_xlsx+'/case_deaths_rate_charts_data_website.xlsx'

columns = Headers.updated_site
row_csv = []

# county-level data (1st url)
url = county_cases_url
resolution = 'county'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
raw_data = response.json()

updated_date = raw_data['LastUpdateDate']
updated = datetime.datetime(updated_date['year'], updated_date['month'],
                            updated_date['day'], 12, 0, 0)
for feature in raw_data['characteristics_by_county']['values']:
    county_name = feature['County']
    # This gives the whole state total
    if county_name == 'Illinois':
        resolution = 'state'
        county = nan
    else:
        resolution = 'county'
        county = county_name

    cases = feature['confirmed_cases']
    tested = feature['total_tested']
    negative_tests = feature['negative']
    deaths = feature['deaths']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, updated, deaths, nan,
        nan, tested, nan, negative_tests,
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

# county-level demographics data (2nd url)
url = county_demo_url
resolution = 'county'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
raw_data = response.json()

updated_date = raw_data['LastUpdateDate']
updated = datetime.datetime(updated_date['year'], updated_date['month'],
                            updated_date['day'], 12, 0, 0)
for feature in raw_data['county_demographics']:
    county = feature['County']
    cases = feature['confirmed_cases']
    tested = feature['total_tested']
    for age in feature['demographics']['age']:
        age_range = age['age_group']
        age_cases = age['count']
        other = 'tested'
        other_value = age['tested']
        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, updated, deaths, nan,
            nan, tested, nan, nan,
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
            other, other_value])

    for race in feature['demographics']['race']:
        other = "Race"
        other_value = race['description']
        cases = race['count']
        tested = race['tested']

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, updated, deaths, nan,
            nan, tested, nan, nan,
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

    for gender in feature['demographics']['gender']:
        sex = gender['description']
        sex_counts = gender['count']
        other = sex + '_tested'
        other_value = gender['tested']
        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
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
            other, other_value])

# zip code-level cases data (3rd url)
url = zipcode_cases_url
resolution = 'zipcode'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
raw_data = response.json()

updated_date = raw_data['LastUpdateDate']
updated = datetime.datetime(updated_date['year'], updated_date['month'],
                            updated_date['day'], 12, 0, 0)
for feature in raw_data['zip_values']:
    region = feature['zip']
    cases = feature['confirmed_cases']
    # tested = feature['total_tested']
    for age in feature['demographics']['age']:
        age_range = age['age_group']
        age_cases = age['count']
        # other = 'tested'
        # other_value = age['tested']
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
            age_range, age_cases, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            nan, nan])

    for race in feature['demographics']['race']:
        for text in ['count']:
            other = race['description'] + '_' + text
            other_value = race[text]
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
                other, other_value])

'''
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

all_df = []

df_column_list = ['updated', 'cases_rate-Latinx', 'cases_rate-Black-non-Latinx',
                  'cases_rate-White-non-Latinx',  'cases_rate-Asian non-Latinx',
                  'cases_rate-Other-non-Latinx', 'deaths_rate-Latinx',
                  'deaths_rate-Black-non-Latinx',
                  'deaths_rate-White-non-Latinx',
                  'deaths_rate-Asian non-Latinx',
                  'deaths_rate-Other-non-Latinx']
url = race_eth_url
df = pd.read_excel(url, sheetname=0, names=df_column_list)
access_time = datetime.datetime.utcnow()
dict_info_chicago = {'provider': 'state', 'country': country, "url": url,
                     "state": state, "resolution": "city",
                     "region": "Chicago",
                     "page": str(df), "access_time": access_time}
for column in df_column_list[1:]:
    placeholder = df[['updated']]
    placeholder['other'] = 'race_ethnicity'
    placeholder['other_value'] = column.replace(
        'cases_rate-', '').replace(
        'deaths_rate-', '')
    tmp_df = df[['updated', column]]
    tmp_df = tmp_df.dropna()
    if 'cases_rate' in column:
        other_name = 'cases_rate'
    else:
        other_name = 'deaths_rate'
    tmp_df['other'] = other_name
    tmp_df = tmp_df.rename(columns={column: 'other_value'})
    all_df.append(pd.concat([tmp_df, placeholder]).sort_values(
        ['updated', 'other_value']))

chicago_df = state_df = fill_in_df(all_df, dict_info_chicago, columns)
'''
now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
