#!/usr/bin/env python3

import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
county_cases_url = 'http://www.vdh.virginia.gov/content/uploads/sites/182/2020/03/VDH-COVID-19-PublicUseDataset-Cases.csv'
state_age_url = 'http://www.vdh.virginia.gov/content/uploads/sites/182/2020/03/VDH-COVID-19-PublicUseDataset-Cases_By-Age-Group.csv'
state_gender_url = 'http://www.vdh.virginia.gov/content/uploads/sites/182/2020/03/VDH-COVID-19-PublicUseDataset-Cases_By-Sex.csv'
state_race_url = 'http://www.vdh.virginia.gov/content/uploads/sites/182/2020/03/VDH-COVID-19-PublicUseDataset-Cases_By-Race.csv'
state = 'Virginia'
columns = Headers.updated_site


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
# county_cases_url
df = pd.read_csv(county_cases_url, header=0, names=['updated', 'fips', 'county',
                                                    'health_district', 'cases'])
access_time = datetime.datetime.utcnow()
dict_info_county_cases = {'provider': 'state', 'country': country,
                          "url": county_cases_url,
                          "state": state, "resolution": "county",
                          "page": str(df), "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_county_cases, columns))

# state_age_url
df = pd.read_csv(state_age_url, header=0, names=['updated', 'age_range',
                                                 'age_cases',
                                                 'age_hospitalized',
                                                 'age_deaths'])
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": state_age_url, "state": state,
                         "resolution": "state", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# state_gender_url
df = pd.read_csv(state_gender_url, header=0, names=['updated', 'sex',
                                                    'sex_counts',
                                                    'hospitalized',
                                                    'sex_death'])
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": state_gender_url, "state": state,
                         "resolution": "state", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases,
                         columns))

# state_race_url
df = pd.read_csv(state_race_url, header=0, names=['updated', 'other_value',
                                                  'cases', 'hospitalized',
                                                  'deaths'])
access_time = datetime.datetime.utcnow()
df['other'] = 'Race'

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": state_race_url, "state": state,
                         "resolution": "state", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.concat(all_df)
df.to_csv(file_name, index=False)

