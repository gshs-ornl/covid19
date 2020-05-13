#!/usr/bin/env python3
"""Scrapes the Virginia provided CSV links."""

import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.webdriver import WebDriver
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
va_url = 'https://www.vdh.virginia.gov/coronavirus/'
base = 'http://www.vdh.virginia.gov/content/uploads/sites/182/2020/'
county_cases_url = f'{base}03/VDH-COVID-19-PublicUseDataset-Cases.csv'
state_age_url = f'{base}03/VDH-COVID-19-PublicUseDataset-Cases_' + \
    'By-Age-Group.csv'
state_gender_url = f'{base}03/VDH-COVID-19-PublicUseDataset-Cases_By-Sex.csv'
state_race_url = f'{base}03/VDH-COVID-19-PublicUseDataset-Cases_By-Race.csv'
health_dist_url = f'{base}04/VDH-COVID-19-PublicUseDataset-' + \
    'Cases_By-District-Death-Hospitalization.csv'
confirmation_url = f'{base}04/VDH-COVID-19-PublicUseDataset-Cases_By' + \
    '-Confirmation.csv'
event_url = f'{base}05/VDH-COVID-19-PublicUseDataset-EventDate.csv'
ethnicity_url = f'{base}05/VDH-COVID-19-PublicUseDataset-Cases_By-' + \
    'Ethnicity.csv'
hosp_url = f'{base}05/VDH-COVID-19-PublicUseDataset-KeyMeasures-Hospitals.csv'
labs_url = f'{base}05/VDH-COVID-19-PublicUseDataset-KeyMeasures-Labs.csv'
state = 'Virginia'
columns = Headers.updated_site


def fill_in_df(df_list, dict_info, columns):
    """Fill in the dataframe."""
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
# county_cases_url {{{1
with WebDriver(url=county_cases_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'fips', 'county', 'health_district', 'cases',
              'hospitalized', 'deaths']
df = df.rename(columns={'health_district': 'region'})
access_time = datetime.datetime.utcnow()
dict_info_county_cases = {'provider': 'state', 'country': country,
                          "url": county_cases_url,
                          "state": state, "resolution": "county",
                          "page": str(df), "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_county_cases, columns))
# 1}}}
# state_age_url {{{1
with WebDriver(url=state_age_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'health_district', 'age_range', 'age_hospitalized',
              'age_deaths', 'age_cases']
df = df.rename(columns={'health_district': 'region'})

access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": state_age_url, "state": state,
                         "resolution": "health district", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# state_gender_url
with WebDriver(url=state_gender_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                            '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'health_district', 'sex', 'sex_counts',
              'hospitalized', 'sex_death']
df = df.rename(columns={'health_district': 'region'})
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": state_gender_url, "state": state,
                         "resolution": "health district", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases,
                         columns))

# state_race_url
with WebDriver(url=state_race_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'health_district', 'other_value', 'cases',
              'hospitalized', 'deaths']
df = df.rename(columns={'health_district': 'region'})
access_time = datetime.datetime.utcnow()
df['other'] = 'Race'

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": state_race_url, "state": state,
                         "resolution": "health district", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# health_dist_url
with WebDriver(url=health_dist_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'region', 'cases', 'hospitalized', 'deaths']
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": health_dist_url, "state": state,
                         "resolution": "health district", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# confirmation_url
with WebDriver(url=confirmation_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'case_status', 'cases', 'hospitalized', 'deaths']
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": confirmation_url, "state": state,
                         "resolution": "state", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# event_url
with WebDriver(url=event_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'case_status', 'cases', 'hospitalized', 'deaths']
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": event_url, "state": state,
                         "resolution": "state", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# ethnicity_url
with WebDriver(url=ethnicity_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'region', 'race', 'cases', 'hospitalized', 'deaths']
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": ethnicity_url, "state": state,
                         "resolution": "health district", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# hosp_url
with WebDriver(url=hosp_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'patients', 'icu', 'patients_on_ventillators',
              'ppe', 'beds_in_use', 'surge_capacity', 'capacity']
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": hosp_url, "state": state,
                         "resolution": "state", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

# key_url
with WebDriver(url=hosp_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                             '--ssl-protocol=any'], sleep_time=15,
               preferences={}) as d:
    df = d.get_csv()
df.columns = ['updated', 'tested', 'positive_tests']
access_time = datetime.datetime.utcnow()

dict_info_state_cases = {'provider': 'state', 'country': country,
                         "url": key_url, "state": state,
                         "resolution": "state", "page": str(df),
                         "access_time": access_time}
all_df.append(fill_in_df(df, dict_info_state_cases, columns))

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.concat(all_df)
df.to_csv(file_name, index=False)
