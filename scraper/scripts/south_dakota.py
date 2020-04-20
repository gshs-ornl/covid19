#!/usr/bin/env python3

import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
url = 'https://doh.sd.gov/news/Coronavirus.aspx'
state = 'South Dakota'
columns = Headers.updated_site

df = pd.read_html(url, match='.*')
access_time = datetime.datetime.utcnow()

state_data = {}


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


# State-level data: cases, negative, hospitalized,recovered
tests = df[0]
hosp_df = df[1]
tested = [tests[tests['Test Results'] == 'Positive*'].drop(
    'Test Results', axis=1).rename(columns={'# of Cases': "cases"})]
negative = [tests[tests['Test Results'] == 'Negative**'].drop(
    'Test Results', axis=1).rename(columns={'# of Cases': "negative"})]

state_data['cases'] = [tests[tests['Test Results'] == 'Positive*'].drop(
    'Test Results', axis=1).values[0][0]]
state_data['negative'] = [tests[tests['Test Results'] == 'Negative**'].drop(
    'Test Results', axis=1).values[0][0]]
state_data['hospitalized'] = [hosp_df[hosp_df[0] == 'Ever Hospitalized*'].drop(
    0, axis=1).values[0][0]]
state_data['recovered'] = [hosp_df[hosp_df[0] == 'Recovered'].drop(
    0, axis=1).values[0][0]]

state_cases_df = pd.DataFrame(state_data)

# State-level data: age group and genders
age_group_df = df[3]
gender_df = df[4]

age_group_df.columns = ['age_range', 'age_cases', 'deaths']
gender_df.columns = ['sex', 'sex_counts', 'deaths']

state_dfs = [state_cases_df, age_group_df, gender_df]


# County-level data: cases, recovered, deaths
county_level_df = df[2]
county_deaths = df[5]
ignored_row = '*Laboratories report COVID-19 testing results to SD-DOH and include patient address that they have received from the medical provider, if available. SD-DOH reports information that we receive from the laboratories, which includes unassigned counties.'
county_level_df.columns = ['county', 'cases', 'negative', 'recovered']
county_deaths.columns = ['county', 'deaths']
county_level_df = county_level_df.merge(county_deaths, on='county', how='outer')
county_level_df = county_level_df[county_level_df['county'] != ignored_row]

# Clean-up data frames
dict_info_state = {'provider': 'state', 'country': country, "url": url,
                   "state": state, "resolution": "state",
                   "page": str(df), "access_time": access_time}

dict_info_county = {'provider': 'state', 'country': country, "url": url,
                    "state": state, "resolution": "county",
                    "page": str(df), "access_time": access_time}

county_level_df = fill_in_df(county_level_df, dict_info_county, columns)
state_level_df = fill_in_df(state_dfs, dict_info_state, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state.replace(' ', '_') + dt_string + '.csv'

# df = pd.DataFrame(row_csv, columns=columns)
df = pd.concat([county_level_df, state_level_df])
df.to_csv(file_name, index=False)
