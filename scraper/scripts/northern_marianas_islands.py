#!/usr/bin/env python3

import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
state = 'Northern Marianas Islands'
columns = Headers.updated_site
web_table_url = 'http://chcc.gov.mp/coronavirusinformation.php'


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

# State-level test data
# Remove the first column
state_df = df[0].drop(0, axis=1)
state_df.columns = ['data', 'value']
# Transpose data frame
state_df = state_df.transpose().reset_index(drop=True)
# Rename the data frame using the first row
state_df.columns = state_df.iloc[0]
# Remove first row as this is duplicated of column names
state_df = state_df.drop(0, axis=0)
# Rename columns
state_df = state_df.rename(
    columns={'Cumulative Number of Confirmed COVID-19 Cases': "cases",
             "Cumulative Number of Persons Released from Quarantine": 'no_longer_monitored',
             'Cumulative Number of Deaths': 'deaths',
             'Cumulative Number of Recovered Cases': 'recovered',
             'Cumulative Number of Persons Tested Through Community Testing Initiative': 'other_value'})
state_df['other'] = 'Cumulative Number of Persons Tested Through Community Testing Initiative'

# Put parsed data in data frame
state_df = fill_in_df(state_df, dict_info_state, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ', '_') + dt_string + '.csv'

df = state_df
df.to_csv(file_name, index=False)
