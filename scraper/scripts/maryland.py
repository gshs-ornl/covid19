#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MD_COVID19_Case_Counts_by_County/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state_cases_url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MASTER_CaseTracker_2/FeatureServer/0/query?f=json&where=Filter%20IS%20NOT%20NULL&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22max%22%2C%22onStatisticField%22%3A%22TotalCases%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_deaths_url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MASTER_CaseTracker_2/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22max%22%2C%22onStatisticField%22%3A%22deaths%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_negative_url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MASTER_CaseTracker_2/FeatureServer/0/query?f=json&where=Filter%20IS%20NOT%20NULL&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22avg%22%2C%22onStatisticField%22%3A%22NegativeTests%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_hospitalized_url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MASTER_CaseTracker_2/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22max%22%2C%22onStatisticField%22%3A%22total_hospitalized%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_isolation_url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MASTER_CaseTracker_2/FeatureServer/0/query?f=json&where=Filter%20IS%20NOT%20NULL&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22max%22%2C%22onStatisticField%22%3A%22total_released%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&resultType=standard&cacheHint=true'
state_demo_url = 'https://coronavirus.maryland.gov/'
state = 'Maryland'
columns = Headers.updated_site
row_csv = []

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
resolution = 'county'
# keys_list = ['EOCStatus']

for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['COUNTY']
    cases = attribute['TotalCaseCount']
    #recovered = attribute['COVID19Recovered']
    deaths = attribute['TotalDeathCount']
    '''
    for key in keys_list:
        other = key
        other_value = attribute[key]
    '''
    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, updated, deaths, nan,
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
            nan, nan])


# State-level data
resolution = 'state'
for url in [state_cases_url, state_deaths_url, state_negative_url,
            state_hospitalized_url, state_isolation_url]:
    response = requests.get(url)
    access_time = datetime.datetime.utcnow()
    updated = determine_updated_timestep(response)
    raw_data = response.json()
    value = raw_data['features'][0]['attributes']['value']

    cases, deaths, negative, hospitalized, no_longer_monitored = nan, nan, nan, nan, nan

    if url == state_cases_url:
        cases = value
    elif url == state_deaths_url:
        deaths = value
    elif url == state_negative_url:
        negative = value
    elif url == state_hospitalized_url:
        hospitalized = value
    elif url == state_isolation_url:
        no_longer_monitored = value
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, nan, deaths, nan,
        nan, nan, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, no_longer_monitored, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])


# State-level data - demographics
def fill_in_df(df_list, dict_info, columns):
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
        df_columns = list(df_list.columns)
        for column in columns:
            if column not in df_columns:
                df_list[column] = nan
            else:
                pass
        final_df = df_list.reindex(columns=columns)
    return final_df


url = state_demo_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
html_text = response.text
soup = BeautifulSoup(html_text, 'html.parser')
data = soup.find_all('script')[3].get_text()[21:]
json_data = json.loads(data)

html_text = json_data['site']['data']['values']['layout']['sections'][4]['rows'][0]['cards'][1]['component']['settings']['markdown']

age_group_df = pd.read_html(html_text)[1][1:11]
age_group_df.columns = ['age_range', 'age_cases', 'age_deaths', 'nan']
age_group_df['age_deaths'] = age_group_df['age_deaths'].str.replace('(', '')
age_group_df['age_deaths'] = age_group_df['age_deaths'].str.replace(')', '')
age_group_df = age_group_df.drop('nan', axis=1)

genders_df = pd.read_html(html_text)[1][11:]
genders_df.columns = ['sex', 'sex_counts', 'other_value', 'nan']
genders_df['other'] = 'deaths'
genders_df['other_value'] = genders_df['other_value'].str.replace('(', '')
genders_df['other_value'] = genders_df['other_value'].str.replace(')', '')
genders_df = genders_df.drop('nan', axis=1)

race_df = pd.read_html(html_text)[2][1:]
race_df.columns = ['other_value', 'cases', 'deaths', 'nan']
race_df['other'] = 'race'
race_df['deaths'] = race_df['deaths'].str.replace('(', '')
race_df['deaths'] = race_df['deaths'].str.replace(')', '')
race_df = race_df.drop('nan', axis=1)

dict_info_state = {'provider': 'state', 'country': country,
                   "url": state_demo_url, "state": state,
                   "resolution": "state", "page": str(soup),
                   "access_time": access_time}

state_df = fill_in_df([age_group_df, genders_df, race_df],
                      dict_info_state, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.concat([pd.DataFrame(row_csv, columns=columns), state_df])
df.to_csv(file_name, index=False)
