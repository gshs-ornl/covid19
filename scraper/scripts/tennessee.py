#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
state = 'Tennessee'
provider = 'state'
county_url = 'https://services1.arcgis.com/YuVBSS7Y1of2Qud1/arcgis/rest/services/TN_Covid_Counties/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=true&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson&token='

state_url = 'https://services1.arcgis.com/YuVBSS7Y1of2Qud1/arcgis/rest/services/TN_Covid_Total/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=Total_Infections%2C+Total_Deaths&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson&token='
state_url_age = 'https://services1.arcgis.com/YuVBSS7Y1of2Qud1/arcgis/rest/services/Dataset_Age/FeatureServer/0/query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&sqlFormat=none&f=pjson&token='
state_url_race_sex = 'https://services1.arcgis.com/YuVBSS7Y1of2Qud1/ArcGIS/rest/services/Dataset_RaceEthSex/FeatureServer/0/query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&sqlFormat=none&f=pjson&token='
state_url_hospital = 'https://services1.arcgis.com/YuVBSS7Y1of2Qud1/ArcGIS/rest/services/Dataset_Daily_Case_Info/FeatureServer/0/query?where=1%3D1&objectIds=&time=&resultType=none&outFields=*&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&sqlFormat=none&f=pjson&token='
columns = Headers.updated_site
row_csv = []

raw_data = requests.get(county_url).json()
access_time = datetime.datetime.utcnow()

resolution = 'county'
dict_info = {'provider': provider, 'country': country, "url": county_url,
             "state": state, "resolution": resolution, "access_time": access_time}


def fill_df(df_list, dict_info, columns):
    df = []
    for each_df in df_list:
        each_df['provider'] = dict_info['provider']
        each_df['country'] = dict_info['country']
        each_df['state'] = dict_info['state']
        each_df['resolution'] = dict_info['resolution']
        each_df['url'] = dict_info['url']
        each_df['access_time'] = dict_info['access_time']
        df_columns = list(each_df.columns)
        for column in columns:
            if column not in df_columns:
                each_df[column] = nan
            else:
                pass
        df.append(each_df.reindex(columns=columns))
    return pd.concat(df)


row_csv_raw = []
for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['NAME']
    cases = attribute['TOTAL_Cases']
    neg_test = attribute['NEG_Tests']
    recovered = attribute['TOTAL_Recovered']
    deaths = attribute["NEW_Deaths"]
    row_csv_raw.append([county, cases, neg_test, recovered, deaths])

df = pd.DataFrame(row_csv_raw, columns=['county', 'cases', 'negative',
                                        'recovered', 'deaths'])

df_list = [df]
county_level_df = fill_df(df_list, dict_info, columns)

##------------------------------------------------------------------------

resolution = 'state'
raw_data = requests.get(state_url_age).json()
access_time = datetime.datetime.utcnow()

state_data = []
for feature in raw_data['features']:
    attribute = feature['attributes']
    day = attribute['Date']
    age_percent = attribute["AR_TotalPercent"]
    age_deaths = attribute["AR_TotalDeaths"]
    age_cases = attribute['AR_CaseCount']
    age_range = attribute['AGE_Label']

    state_data.append([day, age_percent, age_deaths, age_cases, age_range])

df_state = pd.DataFrame(state_data, columns=["date", "age_percent", "age_death", "age_cases", "age_range"])
most_recent = df_state.date.max()
df_most_recent = df_state[df_state.date == most_recent]

for age in df_most_recent.age_range.values:
    age_cases = df_most_recent[df_most_recent.age_range == age]["age_cases"].values[0]
    age_percent = df_most_recent[df_most_recent.age_range == age]["age_percent"].values[0]*100
    age_deaths = df_most_recent[df_most_recent.age_range == age]["age_death"].values[0]
    row_csv.append([
        'state', country, state, nan,
        state_url_age, nan, access_time, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age, age_cases, age_percent, age_deaths,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])

##----------------------------------------------------------------------
raw_data = requests.get(state_url_hospital).json()
access_time = datetime.datetime.utcnow()
state_data_hospital = []
for feature in raw_data['features']:
    attribute = feature['attributes']
    day = attribute['Date']
    hospitalized = attribute["TOTAL_Hosp"]
    recovered = attribute["TOTAL_Recovered"]
    cases = attribute["TOTAL_Cases"]
    deaths = attribute["TOTAL_Deaths"]
    tested = attribute["TOTAL_Tests"]
    neg = attribute["NEG_Tests"]

    state_data.append([day, hospitalized, recovered, cases, deaths, tested, neg])

df_state = pd.DataFrame(state_data, columns=["date", "hospital", "recovered", "cases", "deaths", "tested", "neg"])
most_recent = df_state.date.max()
df_most_recent = df_state[df_state.date == most_recent]

cases = df_most_recent["cases"].values[0]
deaths = df_most_recent["deaths"].values[0]
recovered = df_most_recent["recovered"].values[0]
hospital = df_most_recent["hospital"].values[0]
tested = df_most_recent['tested'].values[0]
neg = df_most_recent["neg"].values[0]
row_csv.append([
    'state', country, state, nan,
    state_url_age, nan, access_time, nan,
    cases, nan, deaths, nan,
    recovered, tested, hospital, neg,
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

# --------------------------------------------------------
resolution = 'state'
raw_data = requests.get(state_url_race_sex).json()
access_time = datetime.datetime.utcnow()

state_data = []
for feature in raw_data['features']:
    attribute = feature['attributes']
    day = attribute['Date']
    cat = attribute["Category"]
    cat_det = attribute["Cat_Detail"]
    cat_case = attribute["Cat_CaseCount"]

    state_data.append([day, cat, cat_det, cat_case])

df_state = pd.DataFrame(state_data, columns=["date", "cat", "cat_det", "cat_case"])
most_recent = df_state.date.max()
df_most_recent = df_state[df_state.date == most_recent]

male = df_most_recent[df_most_recent.cat_det == "Male"]["cat_case"].values[0]
female = df_most_recent[df_most_recent.cat_det == "Female"]["cat_case"].values[0]
row_csv.append([
    'state', country, state, nan,
    state_url_age, nan, access_time, nan,
    nan, nan, nan, nan,
    nan, nan, nan, nan,
    nan, nan, nan, nan, nan,
    nan, nan, nan,
    nan, nan, nan,
    nan, nan, nan,
    resolution, nan, male, female,
    nan, nan, nan, nan,
    nan, nan, nan, nan,
    nan, nan, nan,
    nan, nan,
    nan, nan, nan, nan,
    nan, nan])


for race in df_most_recent[df_most_recent.cat == "RACE"]["cat_det"].values:
    race_cases = df_most_recent[df_most_recent.cat_det == race]["cat_case"].values[0]

    row_csv.append([
        'state', country, state, nan,
        state_url_age, nan, access_time, nan,
        race_cases, nan, nan, nan,
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
        "race", race])

# -----------------------------------------------------

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
all_df = pd.concat([df, county_level_df])
all_df.to_csv(file_name, index=False)
