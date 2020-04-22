#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
date_url_xlsx = (datetime.datetime.today()).strftime('%Y%m%d')
url = 'https://services5.arcgis.com/f2aRfVsQG7TInso2/ArcGIS/rest/services/County_COVID19/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson&token='
# county_csv = 'https://coronavirus.in.gov/map-test/covid_report_county.csv'
county_xlsx = 'https://hub.mph.in.gov/dataset/89cfa2e3-3319-4d31-a60d-710f76856588/resource/8b8e6cd7-ede2-4c41-a9bd-4266df783145/download/covid_report_county_'+date_url_xlsx+'.xlsx'
state_cases = 'https://www.coronavirus.in.gov/map-test/covid-19-indiana-daily-report-current.topojson'
state = 'Indiana'
resolution = 'county'
columns = Headers.updated_site
row_csv = []

raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['COUNTYNAME']
    tested = attribute['Total_Tested']
    cases = attribute['Total_Positive']
    deaths = attribute['Total_Deaths']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, nan, deaths, nan,
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
        nan, nan])


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


url = county_xlsx
raw_data = pd.read_excel(url, sheet_name='Report')
access_time = datetime.datetime.utcnow()
raw_data.columns = ['county', 'cases', 'deaths', 'tested']

dict_info_county = {'provider': 'state', 'country': country, "url": url,
                    "state": state, "resolution": "county",
                    "page": str(raw_data), "access_time": access_time}

county_df = fill_in_df(raw_data, dict_info_county, columns)


url = state_cases
resolution = 'state'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

feature = raw_data['objects']
for gender in feature['viz_gender']:
    sex = gender['GENDER']
    sex_counts = gender['COVID_COUNT']
    sex_percent = gender['COVID_COUNT_PCT']
    deaths = gender['COVID_DEATHS']
    other = 'COVID_DEATHS_PCT'
    other_value = gender[other]

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        nan, nan, deaths, nan,
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
        nan, sex, sex_counts, sex_percent,
        other, other_value])

for age_group in feature['viz_agegrp']:
    age_range = age_group['AGEGRP']
    age_cases = age_group['COVID_COUNT']
    age_percent = age_group['COVID_COUNT_PCT']
    age_deaths = age_group['COVID_DEATHS']
    age_deaths_percent = age_group['COVID_DEATHS_PCT']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age_range, age_cases, age_percent, age_deaths,
        nan, nan, nan,
        nan, nan,
        age_deaths_percent, nan, nan, nan,
        nan, nan])

for race in feature['viz_race']:
    for key in ['RACE', 'POPULATION_PCT', 'COVID_COUNT_PCT',
                'COVID_DEATHS_PCT']:
        other = key
        other_value = race[other]
        cases = race['COVID_COUNT']
        deaths = race['COVID_DEATHS']

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            cases, nan, deaths, nan,
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

for ethnicity in feature['viz_ethnicity']:
    cases = ethnicity['COVID_COUNT']
    deaths = ethnicity['COVID_DEATHS']
    for key in ['ETHNICITY', 'POPULATION_PCT', 'COVID_COUNT_PCT',
                'COVID_DEATHS_PCT']:
        other = key
        other_value = ethnicity[other]

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            cases, nan, deaths, nan,
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

vent = feature['viz_ventbed']
for key in vent.keys():
    other = key
    other_value = vent[other]

    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
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

stat = feature['daily_statistics']
cases = stat['total_case']
deaths = stat['total_death']
tested = stat['total_test']
for key in ['new_case_day', 'new_death_day', 'new_test_day', 'new_case',
            'new_death', 'new_test']:
    other = key
    other_value = stat[other]

    row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            cases, nan, deaths, nan,
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


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.concat([pd.DataFrame(row_csv, columns=columns), county_df])
df.to_csv(file_name, index=False)
