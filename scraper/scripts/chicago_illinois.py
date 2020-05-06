#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
region = 'Chicago'
state = 'Illinois'
resolution = 'city'
url = 'https://www.chicago.gov/city/en/sites/covid-19/home/latest-data.html'
columns = Headers.updated_site
row_csv = []


def fill_in_df_chicago(df_list, dict_info, columns):
    if isinstance(df_list, list):
        all_df = []
        count = 1
        for each_df in df_list:
            if isinstance(each_df, pd.DataFrame):
                each_df['provider'] = dict_info['provider']
                each_df['country'] = dict_info['country']
                each_df['state'] = dict_info['state']
                each_df['resolution'] = dict_info['resolution']
                each_df['url'] = dict_info['url']
                each_df['page'] = str(dict_info['page'])
                each_df['access_time'] = dict_info['access_time']
                each_df['region'] = dict_info['region']
                df_columns = list(each_df.columns)
                for column in columns:
                    if column not in df_columns:
                        each_df[column] = nan
                    else:
                        pass
                all_df.append(each_df.reindex(columns=columns))
            else:
                print(df_list[count], "Not dataframe ", type(each_df))
            count = count + 1
        final_df = pd.concat(all_df)
    else:
        df_list['provider'] = dict_info['provider']
        df_list['country'] = dict_info['country']
        df_list['state'] = dict_info['state']
        df_list['resolution'] = dict_info['resolution']
        df_list['url'] = dict_info['url']
        df_list['page'] = str(dict_info['page'])
        df_list['access_time'] = dict_info['access_time']
        df_list['region'] = dict_info['region']
        df_columns = list(df_list.columns)
        for column in columns:
            if column not in df_columns:
                df_list[column] = nan
            else:
                pass
        final_df = df_list.reindex(columns=columns)
    return final_df


df = pd.read_html(url, match='.*')
access_time = datetime.datetime.utcnow()
dict_info_city = {'provider': 'state', 'country': country,
                  "url": url, 'region': region, "state": state,
                  "resolution": resolution, "page": str(df),
                  "access_time": access_time}

chicago_case = df[0]
chicago_characteristics_deaths = df[1]
chicago_characteristics_cases = df[2]
underlying_deaths = df[3]

# Chicago cases
chicago_case = chicago_case.rename(columns={'GEOGRAPHY': 'region',
                                            'CASES1': 'cases',
                                            'DEATHS': 'deaths'})
chicago_case = chicago_case[chicago_case['region'] == 'Chicago']

# Chicago characteristics - deaths
# Chicago deaths - overall
chicago_deaths = chicago_characteristics_deaths[chicago_characteristics_deaths['CHARACTERISTIC'] == 'Chicago']
chicago_deaths = chicago_deaths.rename(
    columns={'CHARACTERISTIC': 'region', 'DEATHS': 'deaths',
             'RATE PER 100,000 POPULATION': 'other_value'})
chicago_deaths['other'] = 'death_rate_per_100000_population'
chicago_deaths = chicago_deaths[['region', 'deaths', 'other', 'other_value']]

# Chicago deaths by age group
age_group_deaths = chicago_characteristics_deaths[2:9]
age_group_deaths = age_group_deaths.rename(
    columns={'CHARACTERISTIC': 'age_range', 'DEATHS': 'age_deaths',
             '% TOTAL DEATHS': 'age_deaths_percent',
             'RATE PER 100,000 POPULATION': 'other_value'})
age_group_deaths['other'] = 'death_rate_per_100000_population'
age_group_deaths = age_group_deaths[['age_range', 'age_deaths',
                                     'age_deaths_percent', 'other',
                                     'other_value']]

# Chicago deaths by gender overall
gender_deaths = chicago_characteristics_deaths[10:13]
# deaths breakdown by gender
gender_deaths1 = gender_deaths[['CHARACTERISTIC', 'DEATHS']].rename(
    columns={'CHARACTERISTIC': 'sex', 'DEATHS': 'other_value'})
gender_deaths1['other'] = 'deaths'

# % total deaths breakdown by gender
gender_percent_death = gender_deaths[['CHARACTERISTIC',
                                      '% TOTAL DEATHS']].rename(
    columns={'CHARACTERISTIC': 'sex', '% TOTAL DEATHS': 'other_value'})
gender_percent_death['other'] = 'percent_total_deaths'

# Rate per 100k population breakdown by gender
gender_rate_pop = gender_deaths[['CHARACTERISTIC', 'RATE PER 100,000 POPULATION']].rename(
    columns={'CHARACTERISTIC': 'sex', 'RATE PER 100,000 POPULATION': 'other_value'})
gender_rate_pop['other'] = 'death_rate_per_100000_population'

# Chicago deaths by race and ethnicity
race_eth_deaths = chicago_characteristics_deaths[14:20]
race_eth_deaths['CHARACTERISTIC'] = race_eth_deaths['CHARACTERISTIC'].str.replace(', ', '_')

race_eth_deaths1 = race_eth_deaths[['CHARACTERISTIC', 'DEATHS']].rename(
    columns={'CHARACTERISTIC': 'other_value', 'DEATHS': 'deaths'})
race_eth_deaths1['other'] = 'race_ethnicity'

# % total deaths breakdown by race and ethnicity
race_eth_percent_death = race_eth_deaths[['CHARACTERISTIC', '% TOTAL DEATHS']].rename(
    columns={'CHARACTERISTIC': 'other', '% TOTAL DEATHS': 'other_value'})
race_eth_percent_death['other'] = race_eth_percent_death['other'] + '_percent_total_deaths'

# Rate per 100k population breakdown by race and ethnicity
race_eth_rate_pop = race_eth_deaths[['CHARACTERISTIC', 'RATE PER 100,000 POPULATION']].rename(
    columns={'CHARACTERISTIC': 'other', 'RATE PER 100,000 POPULATION': 'other_value'})
race_eth_rate_pop['other'] = race_eth_rate_pop['other'] + '_death_rate_per_100000_population'


# Chicago - cases characteristics
chicago_char_cases = chicago_characteristics_cases[0:1].rename(
    columns={'CHARACTERISTIC': 'Region', 'NUMBER': 'cases',
             'RATE PER 100,000': 'other_value'})
chicago_char_cases = chicago_char_cases.drop('% TOTAL CASES(1)', axis=1)
chicago_char_cases['other'] = 'cases_rate_per_100000'

# Chicago - cases by age group - Rate per 100k
age_group_cases_rate_per_100000 = chicago_characteristics_cases[2:10].rename(
    columns={'CHARACTERISTIC': 'age_range', 'NUMBER': 'age_cases',
             'RATE PER 100,000': 'other_value'}).drop(
    '% TOTAL CASES(1)', axis=1)
age_group_cases_rate_per_100000['other'] = 'cases_rate_per_100000'

# Chicago - cases by age group - % total cases
age_group_cases_pct = chicago_characteristics_cases[2:10].rename(
    columns={'CHARACTERISTIC': 'age_range', 'NUMBER': 'age_cases',
             '% TOTAL CASES(1)': 'other_value'}).drop(
    'RATE PER 100,000', axis=1)
age_group_cases_pct['other'] = 'cases_percent_total_cases'

# Chicago - cases by gender - Rate per 100k
gender_cases_rate_per_100000 = chicago_characteristics_cases[11:14].rename(
    columns={'CHARACTERISTIC': 'sex', 'NUMBER': 'sex_counts',
             'RATE PER 100,000': 'other_value'}).drop(
    '% TOTAL CASES(1)', axis=1)
gender_cases_rate_per_100000['other'] = 'cases_rate_per_100000'

# Chicago - cases by gender - % total cases
gender_cases_pct = chicago_characteristics_cases[11:14].rename(
    columns={'CHARACTERISTIC': 'age_range', 'NUMBER': 'age_cases',
             '% TOTAL CASES(1)': 'other_value'}).drop(
    'RATE PER 100,000', axis=1)
gender_cases_pct['other'] = 'cases_percent_total_cases'

# Chicago cases by race and ethnicity
race_eth_cases = chicago_characteristics_cases[15:21]
race_eth_cases['CHARACTERISTIC'] = race_eth_cases['CHARACTERISTIC'].str.replace(', ', '_')

race_eth_cases1 = race_eth_cases[['CHARACTERISTIC', 'NUMBER']].rename(
    columns={'CHARACTERISTIC': 'other_value', 'NUMBER': 'cases'})
race_eth_cases1['other'] = 'race_ethnicity'

# % total cases breakdown by race and ethnicity
race_eth_percent_case = race_eth_cases[['CHARACTERISTIC',
                                        '% TOTAL CASES(1)']].rename(
    columns={'CHARACTERISTIC': 'other', '% TOTAL CASES(1)': 'other_value'})
race_eth_percent_case['other'] = race_eth_percent_case['other'] + '_percent_total_cases'

# Rate per 100k population breakdown by race and ethnicity
race_eth_rate = race_eth_cases[['CHARACTERISTIC', 'RATE PER 100,000']].rename(
    columns={'CHARACTERISTIC': 'other', 'RATE PER 100,000': 'other_value'})
race_eth_rate['other'] = race_eth_rate['other'] + '_case_rate_per_100000_population'

# Deaths - underlying conditions
total_know_med_hist = underlying_deaths[0:1].rename(
    columns={'CHARACTERISTIC': 'other', 'NUMBER': 'deaths',
             '% OF KNOWN': 'other_value'})
total_know_med_hist['other'] = total_know_med_hist['other'].str.replace(' ', '_') + '_percent_of_known'

underlying_con = underlying_deaths[1:4].rename(
    columns={'CHARACTERISTIC': 'other', 'NUMBER': 'deaths',
             '% OF KNOWN': 'other_value'})
underlying_con['other'] = underlying_con['other'].str.replace(' ', '_') + '_percent_of_known'


dfs = [chicago_case, chicago_deaths, age_group_deaths, gender_deaths1,
       gender_percent_death, gender_rate_pop,
       race_eth_deaths1, race_eth_percent_death, race_eth_rate_pop,
       chicago_char_cases, age_group_cases_rate_per_100000, age_group_cases_pct,
       gender_cases_rate_per_100000, gender_cases_pct,
       race_eth_cases1, race_eth_percent_case, race_eth_rate,
       total_know_med_hist, underlying_con]

df = fill_in_df_chicago(dfs, dict_info_city, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if not path.endswith('/'):
    path += '/'
file_name = path + region + '_' + state + dt_string + '.csv'


df.to_csv(file_name, index=False)
