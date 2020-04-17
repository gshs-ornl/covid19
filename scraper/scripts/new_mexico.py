#!/usr/bin/env python3

import datetime
import os
import requests
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
county_cases_url = 'https://e7p503ngy5.execute-api.us-west-2.amazonaws.com/prod/GetCounties'
state_cases_url = 'https://e7p503ngy5.execute-api.us-west-2.amazonaws.com/prod/GetPublicStatewideData'
state = 'New Mexico'
columns = Headers.updated_site

row_csv = []

resolution = 'county'
url = county_cases_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

age_group = ['0-9', '10-19', '20-29', '30-39', '40-49', '50-59', '60-69',
             '70-79', '80-89', '90+']
gender_list = ['male', 'female']

for data in raw_data['data']:
    county = data['name']
    cases = data['cases']
    deaths = data['deaths']
    tested = data['tests']
    for age in age_group:
        age_range = age
        age_cases = data[age]
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
            age_range, age_cases, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            nan, nan])

    for gender in gender_list:
        sex = gender
        sex_counts = data[gender]
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
            nan, sex, sex_counts, nan,
            nan, nan])


resolution = 'state'
url = state_cases_url
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

age_group.append('ageNR')
gender_list.append('genderNR')
race_other_list = ['amInd', 'asian', 'black', 'hawaiian', 'unknown', 'other',
                   'white', 'hispanic', 'currentHospitalizations']

data = raw_data['data']
cases = data['cases']
tested = data['tests']
hospitalized = data['totalHospitalizations']
deaths = data['deaths']
recovered = data['recovered']

for age in age_group:
    age_range = age
    age_cases = data[age]
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, nan, deaths, nan,
        recovered, tested, hospitalized, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age_range, age_cases, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])

for gender in gender_list:
    sex = gender
    sex_counts = data[gender]
    row_csv.append(['state', country, state, nan,
                    url, str(raw_data), access_time, nan,
                    cases, nan, deaths, nan,
                    recovered, tested, hospitalized, nan,
                    nan, nan, nan, nan, nan,
                    nan, nan, nan,
                    nan, nan, nan,
                    nan, nan, nan,
                    resolution, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan,
                    nan, nan,
                    nan, sex, sex_counts, nan,
                    nan, nan])

for race in race_other_list:
    other = race
    other_value = data[other]
    row_csv.append(['state', country, state, nan,
                    url, str(raw_data), access_time, nan,
                    cases, nan, deaths, nan,
                    recovered, tested, hospitalized, nan,
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
file_name = path + state.replace(' ', '_') + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=Headers.updated_site)
df.to_csv(file_name, index=False)

