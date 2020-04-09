#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
url = 'https://services.arcgis.com/qnjIrwR8z5Izc0ij/ArcGIS/rest/services/COVID_Cases_Production_View/FeatureServer/0/query?f=json&where=Total%20%3C%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=NewCases%20desc%2CNAMELABEL%20asc&resultOffset=0&resultRecordCount=56&cacheHint=true'
state_url_tested = 'https://services.arcgis.com/qnjIrwR8z5Izc0ij/ArcGIS/rest/services/COVID_Cases_Production_View/FeatureServer/1/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Total_Tests_Completed%20desc&resultOffset=0&resultRecordCount=1&cacheHint=true'
state = 'Montana'

columns = Headers.updated_site
row_csv = []

# County level
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
resolution = 'county'

age_keys = ['0_9', '10_19', '20_29', '30_39', '40_49', '50_59',
            '60_69', '70_79', '80_89', '90_99', '100']

state_cases = []
state_deaths = []
state_hospitalized = []
state_recovered = []
state_female_raw = []
state_male_raw = []
state_age_group = {}

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['NAMELABEL']
    cases = attribute['Total']
    deaths = attribute['TotalDeaths']
    hospitalized = attribute['HospitalizationCount']
    recovered = attribute['TotalRecovered']

    state_cases.append(int(cases))
    state_deaths.append(int(deaths))
    state_hospitalized.append(int(hospitalized))
    state_recovered.append(int(recovered))

    female_raw = []
    male_raw = []
    for age_key in age_keys:
        age_range = age_key
        age_cases = attribute['T_' + age_key]
        if state_age_group.get(age_key) is None:
            state_age_group[age_key] = []
        else:
            state_age_group[age_key].append(int(age_cases))

        female_case = attribute['F_'+age_key]
        male_case = attribute['M_' + age_key]
        female_raw.append(int(female_case))
        male_raw.append(int(male_case))
        state_female_raw.append(int(female_case))
        state_male_raw.append(int(male_case))

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, nan, deaths, nan,
            recovered, nan, hospitalized, nan,
            nan, nan, nan, nan, nan,
            nan,  nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            age_range, age_cases, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            nan, nan])

    for gender in ['Female', 'Male']:
        sex = gender
        if gender == 'Female':
            sex_count = sum(female_raw)
        elif gender == 'Male':
            sex_count = sum(male_raw)

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, nan, deaths, nan,
            recovered, nan, hospitalized, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, sex, sex_count, nan,
            nan, nan])


resolution = 'state'

state_age_group_keys = list(state_age_group.keys())
cases = sum(state_cases)
deaths = sum(state_deaths)
hospitalized = sum(state_hospitalized)
recovered = sum(state_recovered)


for state_age_group_key in state_age_group_keys:
    age_range = state_age_group_key
    age_cases = sum(state_age_group[state_age_group_key])

    row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, nan,
                cases, nan, deaths, nan,
                recovered, nan, hospitalized, nan,
                nan, nan, nan, nan, nan,
                nan,  nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                resolution, nan, nan, nan,
                nan, nan, nan, nan,
                age_range, age_cases, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                nan, nan])


for gender in ['Female', 'Male']:
    sex = gender
    if gender == 'Female':
        sex_count = sum(state_female_raw)
    elif gender == 'Male':
        sex_count = sum(state_male_raw)

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, nan, deaths, nan,
        recovered, nan, hospitalized, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, sex, sex_count, nan,
        nan, nan])

with open(state+'county_data.json', 'w') as f:
    json.dump(raw_data, f)

# State level - tests
raw_data = requests.get(state_url_tested).json()
access_time = datetime.datetime.utcnow()
tested = raw_data['features'][0]['attributes']['Total_Tests_Completed']

row_csv.append([
        'state', country, state, nan,
        state_url_tested, str(raw_data), access_time, nan,
        nan, nan, nan, nan,
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

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
