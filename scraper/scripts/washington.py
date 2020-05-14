#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from bs4 import BeautifulSoup
from cvpy.webdriver import WebDriver
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
county_url = 'https://services8.arcgis.com/rGGrs6HCnw87OFOT/arcgis/rest/services/CountyCases/FeatureServer/0/query?f=json&where=(CV_PositiveCases%20%3E%200)%20AND%20(CV_PositiveCases%3E0)&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=CNTY_NAME%20asc&resultOffset=0&resultRecordCount=39&resultType=standard&cacheHint=true'
state_web_url = 'https://www.doh.wa.gov/Emergencies/Coronavirus'

state = 'Washington'
columns = Headers.updated_site
row_csv = []

# county-state data
url = county_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
resolution = 'county'

state_cases = None
state_deaths = None
state_updated = None

other_attributes = ['CV_Cases_Today', 'CV_Deaths_Today', 'CV_Comment']

for feature in raw_data['features']:
    attribute = feature['attributes']
    update_date = float(attribute['CV_Updated'])
    updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))

    county = attribute['CNTY_NAME']
    cases = attribute['CV_PositiveCases']
    deaths = attribute['CV_Deaths']

    if state_cases is None:
        state_cases = attribute['CV_State_Cases']
        if state_updated is None:
            state_updated = updated
    if state_deaths is None:
        state_deaths = attribute['CV_State_Deaths']
        if state_updated is None:
            state_updated = updated

    for other_attribute in other_attributes:
        if other_attribute == 'CV_Comment':
            interested_txt = 'Phase 1 reopening beginning'
            reopen_date = attribute[other_attribute]
            if interested_txt in reopen_date:
                other_value = reopen_date.split(interested_txt)[1]
                other = interested_txt
            else:
                other, other_value = nan, nan
        else:
            other = other_attribute
            other_value = attribute[other_attribute]

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
                other, other_value])

# Added the state data here
resolution = 'state'
cases = state_cases
deaths = state_deaths
updated = state_updated
row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
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

# Web-table
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


with WebDriver(url=state_web_url, driver='chromedriver',
               options=['--no-sandbox', '--disable-gpu',
                        '--disable-logging',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--no-zygote', 'headless'],
               service_args=['--ignore-ssl-errors=true',
                            '--ssl-protocol=any']) as d:
               #preferences={})
    # test = d.get_class('find_element_by_class_name')
    source = d.driver.page_source
access_time = datetime.datetime.utcnow()

dict_info_county = {'provider': 'state', 'country': country,
                    "url": state_web_url,
                    "state": state, "resolution": "county",
                    "page": str(source), "access_time": access_time}

dict_info_state = {'provider': 'state', 'country': country,
                   "url": state_web_url,
                   "state": state, "resolution": "state",
                   "page": str(source), "access_time": access_time}

df = pd.read_html(source, match='.*')

test_df = df[5]
hospitalized_df = df[6]
# Race/Ethnicity - cases
race_df = df[9]
# Race/Ethnicity - deaths
race_df1 = df[10]

county_df = df[4].rename(columns={
    'County': 'county', 'Confirmed Cases': 'cases', 'Deaths': 'deaths'})

age_group_df = df[7].rename(columns={
    'Age Group': 'age_range',
    'Percent of Cases': 'age_percent',
    'Percent of Deaths': 'age_deaths_percent'
})

# Total test
tested_df = pd.DataFrame([test_df['Individuals Tested'].sum()],
                         columns=['tested'])

# Negative test
other_test_attr_name = 'Percent of Tests'
test_df['other'] = other_test_attr_name
neg_test_df = test_df[test_df['Result'] == 'Negative']

neg_test_df = neg_test_df.rename(columns={'Individuals Tested': 'negative',
                                         other_test_attr_name: 'other_value'})
neg_test_df = neg_test_df.drop('Result', axis=1)

# Hospitalization
other_hosp_attr_name = 'Hospitals Reporting'
hospitalized_df['other'] = other_hosp_attr_name
hospitalized_df = hospitalized_df.rename(columns={
    'Date': 'updated', other_hosp_attr_name: 'other_value',
    'Total Patients Hospitalized with COVID‑19': 'hospitalized',
    'Total Patients in the ICU with COVID‑19': 'icu'})

# Gender
other_gender_attr_name = 'Percent of Deaths'
gender_df = df[8].rename(columns={
    'Sex at Birth': 'sex', 'Percent of Cases': 'sex_percent',
    other_gender_attr_name: 'other_value'})
gender_df['other'] = other_gender_attr_name

# Race/Ethnicity - cases
race_df = race_df[(race_df['Race/Ethnicity'] != 'Total Number of Cases') &
                  (race_df['Race/Ethnicity'] != 'Total with Race/Ethnicity Available')]
race_df = race_df.drop('Percent of Total WA Population', axis=1)
race_df.columns = ['Race/Ethnicity', 'Confirmed Cases', 'percent of cases']

# cases
race_cases_df = race_df[['Race/Ethnicity', 'Confirmed Cases']]
race_cases_df = race_cases_df.rename(columns={'Race/Ethnicity': 'other',
                                     'Confirmed Cases': 'other_value'})
race_cases_df['other'] = 'cases_' + race_cases_df['other']

# Percent of cases
race_pct_cases_df = race_df[['Race/Ethnicity',
                             'percent of cases']]
race_pct_cases_df = race_pct_cases_df.rename(columns={
    'Race/Ethnicity': 'other', 'percent of cases': 'other_value'})
race_pct_cases_df['other'] = 'percent_of_cases_' + race_pct_cases_df['other']


# Race/Ethnicity - deaths
race_df1 = race_df1[(race_df1['Race/Ethnicity'] != 'Total Number of Deaths') &
                 (race_df1['Race/Ethnicity'] != 'Total with Race/Ethnicity Available')]
race_df1 = race_df1.drop('Percent of Total WA Population', axis=1)
race_df1.columns = ['Race/Ethnicity', 'Deaths', 'percent of deaths']

# cases
race_deaths_df = race_df1[['Race/Ethnicity', 'Deaths']]
race_deaths_df = race_deaths_df.rename(columns={
    'Race/Ethnicity': 'other', 'Deaths': 'other_value'})
race_deaths_df['other'] = 'deaths_' + race_deaths_df['other']

# Percent of cases
race_pct_deaths_df = race_df1[['Race/Ethnicity',
                             'percent of deaths']]
race_pct_deaths_df = race_pct_deaths_df.rename(columns={
    'Race/Ethnicity': 'other', 'percent of deaths': 'other_value'})
race_pct_deaths_df['other'] = 'percent of deaths_' + race_pct_deaths_df['other']

county_df = county_df
state_df = [tested_df, neg_test_df, hospitalized_df, age_group_df,
             race_cases_df, race_pct_cases_df,
             race_deaths_df, race_pct_deaths_df]

county_df = fill_in_df(county_df, dict_info_county, columns)
state_df = fill_in_df(state_df, dict_info_state, columns)
now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.concat([pd.DataFrame(row_csv, columns=columns), county_df, state_df])

#df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
