#!/usr/bin/env python3
"""Scrape Missisippi Sources."""
import os
import re
import camelot
import requests
import datetime
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
state = 'Mississippi'
columns = Headers.updated_site
new_column_names = ['black_cases', 'white_cases',
           'native_cases', 'asian_cases', 'other_race_cases',
           'unknown_race_cases', 'black_deaths',
           'white_deaths', 'native_deaths', 'asian_deaths',
           'other_race_deaths', 'unknown_race_deaths']
columns.extend(new_column_names)
web_table_url = 'https://msdh.ms.gov/msdhsite/_static/14,0,420.html'


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


df = pd.read_html(web_table_url, match='.*')
access_time = datetime.datetime.utcnow()
dict_info_state = {'provider': 'state', 'country': country,
                   "url": web_table_url,
                   "state": state, "resolution": "state",
                   "page": str(df), "access_time": access_time}

dict_info_county = {'provider': 'state', 'country': country,
                    "url": web_table_url,
                    "state": state, "resolution": "county",
                    "page": str(df), "access_time": access_time}
df = pd.read_html(web_table_url, match='.*')
access_time = datetime.datetime.utcnow()
dict_info_state = {'provider': 'state', 'country': country,
                   "url": web_table_url,
                   "state": state, "resolution": "state",
                   "page": str(df), "access_time": access_time}

dict_info_county = {'provider': 'state', 'country': country,
                    "url": web_table_url,
                    "state": state, "resolution": "county",
                    "page": str(df), "access_time": access_time}

# Daily deaths for today
county_deaths_today_df = df[0]
county_deaths_today_df = county_deaths_today_df.rename(
        columns={"County": "county", "Deaths reported today": 'other_value'})
county_deaths_today_df['other'] = 'Deaths reported today'

# County-level data
county_level_df = df[1].rename(
        columns={"County": "county", "Total Cases": 'cases',
                 "Total Deaths": 'deaths'})
ltc_cases_txt = 'Total LTC Facility Cases'
county_ltc_cases = county_level_df[['county', ltc_cases_txt]]
county_ltc_cases = county_ltc_cases.rename(
        columns={ltc_cases_txt: 'other_value'})
county_ltc_cases['other'] = ltc_cases_txt

ltc_deaths_txt = 'Total LTC Facility Deaths'
county_ltc_deaths = county_level_df[['county', 'Total LTC Facility Deaths']]
county_ltc_deaths = county_ltc_deaths.rename(
        columns={ltc_deaths_txt: 'other_value'})
county_ltc_deaths['other'] = ltc_deaths_txt

county_level_df = county_level_df[['county', 'deaths', 'cases']]

cases_deaths_state_level_df = county_level_df[
        county_level_df['county'] == 'Total'].drop('county', axis=1)

county_level_df = county_level_df[county_level_df['county'] != 'Total']

# Put parsed data in data frame
county_level_df = fill_in_df([county_level_df, county_deaths_today_df,
                              county_ltc_cases, county_ltc_cases],
                             dict_info_county, columns)
cases_deaths_state_level_df = fill_in_df(cases_deaths_state_level_df,
                                         dict_info_state, columns)

# County & State level test data
cnty_df = df[1]
cnty_df.columns = ['county', 'cases', 'deaths', 'LTC Facility Cases',
                   'LTC Facility Deaths']
county_dat = cnty_df[:81]
state_dat = cnty_df.head(-81)

state_data = fill_in_df(county_dat, dict_info_county, cnty_df.columns)
county_data = fill_in_df(state_dat, dict_info_state, state_dat.columns)

# State-level test data
test_df = df[2]
test_df.columns = ['description', 'tested']
total_test = test_df[
        test_df['description'] == "Total individuals tested for COVID-19"
                                  " statewide"][['tested']]
other_test = test_df[0:2]
other_test.columns = ['other', 'other_value']

# Put parsed data in data frame
state_total_test = fill_in_df(total_test, dict_info_state, columns)
state_total_lab_test = fill_in_df(other_test, dict_info_state, columns)

# PDF 1
url = 'https://msdh.ms.gov/msdhsite/_static/resources/8573.pdf'
r = requests.get(url, allow_redirects=True)
temp = '/tmp/pdf1.pdf'
open(temp, 'wb').write(r.content)
pdf = camelot.read_pdf(temp)
os.remove(temp)
df1 = pdf[0].df
new_header = df1.iloc[2].str.replace(r'\n', '')
df1 = df1[3:]
df1.columns = new_header
df_tot = df1[['County', 'Total Cases']]
df1.drop('Total Cases', axis=1)
dfm = pd.melt(df1, id_vars=['County'], var_name='race')
df_tot.columns = ['county', 'cases']
dict_info_county = {'provider': 'state', 'country': country,
                    "url": web_table_url,
                    "state": state, "resolution": "county",
                    "page": str(df1), "access_time": access_time}

county_cases = fill_in_df(df_tot, dict_info_county, columns)
race_cases = fill_in_df(dfm, dict_info_county, columns)

# PDF 2
url = 'https://msdh.ms.gov/msdhsite/_static/resources/8578.pdf'
r = requests.get(url, allow_redirects=True)
temp = '/tmp/pdf1.pdf'
open(temp, 'wb').write(r.content)
pdf = camelot.read_pdf(temp)
os.remove(temp)
df1 = pdf[0].df
new_header = df1.iloc[1].str.replace(r'\n', '')
df1 = df1[2:]
ltc_dict_info = {'provider': 'state', 'country': country,
                 'url': url,
                 'state': state, 'resolution': 'LTC and RC Facilities',
                 'page': str(df1), "access_time": access_time}
headers = ['county', 'active', 'cases', 'black_cases', 'white_cases',
           'native_cases', 'asian_cases', 'other_race_cases',
           'unknown_race_cases', 'deaths', 'black_deaths',
           'white_deaths', 'native_deaths', 'asian_deaths',
           'other_race_deaths', 'unknown_race_deaths']
df1.columns = headers
ltcdf = fill_in_df(df1, ltc_dict_info, columns)


# Put parsed data in data frame
state_total_test = fill_in_df(total_test, dict_info_state, columns)
state_total_lab_test = fill_in_df(other_test, dict_info_state, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ', '_') + dt_string + '.csv'
print('county_level_df', county_level_df.shape)
print('cases_deaths_state_level_df', cases_deaths_state_level_df.shape)
print('state_total_test', state_total_test.shape)
print('state_total_lab_test', state_total_lab_test.shape)
print('race_cases', race_cases.shape)
print('county_cases', county_cases.shape)
print('ltcdf', ltcdf.shape)
print(cases_deaths_state_level_df)

df = pd.concat([county_level_df, cases_deaths_state_level_df,
                state_total_test, state_total_lab_test, race_cases,
                county_cases, ltcdf])
df.to_csv(file_name, index=False)
