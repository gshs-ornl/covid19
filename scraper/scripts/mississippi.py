#!/usr/bin/env python3

import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
state = 'Mississippi'
columns = Headers.updated_site
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

# County-level data
county_level_df = df[0]
county_level_df = county_level_df.rename(
    columns={"County": "county", "Total Cases": 'cases',
             "Total Deaths": 'deaths',
             "Total Cases in LTC Facilities": 'other_value'})
county_level_df['other'] = "Total Cases in LTC Facilities"

cases_deaths_state_level_df = county_level_df[
    county_level_df['county'] == 'Total'].drop('county', axis=1)

county_level_df = county_level_df[county_level_df['county'] != 'Total']

# Put parsed data in data frame
county_level_df = fill_in_df(county_level_df, dict_info_county, columns)
cases_deaths_state_level_df = fill_in_df(cases_deaths_state_level_df,
                                         dict_info_state, columns)

# State-level test data
test_df = df[1]
test_df.columns = ['description', 'tested']
total_test = test_df[
    test_df['description'] == "Total individuals tested for COVID-19" \
                              " statewide"][['tested']]
other_test = test_df[0:2]
other_test.columns = ['other', 'other_value']

# Put parsed data in data frame
state_total_test = fill_in_df(total_test, dict_info_state, columns)
state_total_lab_test = fill_in_df(other_test, dict_info_state, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ', '_') + dt_string + '.csv'

df = pd.concat([county_level_df, cases_deaths_state_level_df,
                state_total_test, state_total_lab_test])
df.to_csv(file_name, index=False)
