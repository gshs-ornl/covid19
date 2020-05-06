#!/usr/bin/env python3

import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.webdriver import WebDriver
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
state = 'Oklahoma'
county_cases_url = 'https://storage.googleapis.com/ok-covid-gcs-public-download/oklahoma_cases_county.csv'
city_cases_url = 'https://storage.googleapis.com/ok-covid-gcs-public-download/oklahoma_cases_city.csv'
zipcode_cases_url = 'https://storage.googleapis.com/ok-covid-gcs-public-download/oklahoma_cases_zip.csv'
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


# county_cases_url
with WebDriver(url=county_cases_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true','--ssl-protocol=any'],
               sleep_time=15, preferences={}) as d:
    df = d.get_csv()
access_time = datetime.datetime.utcnow()

county_df = df.rename(
    columns={'County': 'county', 'Cases': 'cases', 'Deaths': 'deaths',
             'Recovered': 'recovered', 'ReportDate': 'updated'})

state_df = county_df.groupby(['updated']).sum().reset_index()

dict_info_county = {'provider': 'state', 'country': country,
                          "url": county_cases_url,
                          "state": state, "resolution": "county",
                          "page": str(df), "access_time": access_time}

dict_info_state = {'provider': 'state', 'country': country,
                          "url": county_cases_url,
                          "state": state, "resolution": "state",
                          "page": str(df), "access_time": access_time}


# city_cases_url
with WebDriver(url=city_cases_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true','--ssl-protocol=any'],
               sleep_time=15, preferences={}) as d:
    df = d.get_csv()
access_time = datetime.datetime.utcnow()

dict_info_city = {'provider': 'state', 'country': country,
                  "url": city_cases_url,
                  "state": state, "resolution": "city",
                  "page": str(df), "access_time": access_time}

city_df_raw = df.rename(
    columns={'City': 'region', 'Cases': 'cases', 'Deaths': 'deaths',
             'Recovered': 'recovered', 'ReportDate': 'updated'})
city_df = city_df_raw[city_df_raw['region'] != 'OTHER***']

# zipcode_cases_url
with WebDriver(url=zipcode_cases_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true', '--ssl-protocol=any'],
               sleep_time=15, preferences={}) as d:
    df = d.get_csv()
access_time = datetime.datetime.utcnow()

dict_info_zipcode = {'provider': 'state', 'country': country,
                  "url": zipcode_cases_url,
                  "state": state, "resolution": "zipcode",
                  "page": str(df), "access_time": access_time}
zipcode_df_raw = df.rename(
    columns={'Zip': 'region', 'Cases': 'cases', 'Deaths': 'deaths',
             'Recovered': 'recovered', 'ReportDate': 'updated'})
zipcode_df = zipcode_df_raw[zipcode_df_raw['region'] != 'Other***']


county_df = fill_in_df(county_df, dict_info_county, columns)
state_df = fill_in_df(state_df, dict_info_state, columns)
city_df = fill_in_df(city_df, dict_info_city, columns)
zipcode_df = fill_in_df(zipcode_df, dict_info_zipcode, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.concat([county_df, state_df, city_df, zipcode_df])
df.to_csv(file_name, index=False)

