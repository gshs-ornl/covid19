#!/usr/bin/env python3

import requests
import pytz
import datetime
import json
import os
from numpy import nan
import pandas as pd
from bs4 import BeautifulSoup, NavigableString, Tag
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

# convenience method to turn off huge data for manual review - use for HTML/JSON
def get_raw_data(html_text):
    return str(html_text)
    #return 'RAW_DATA_REMOVED_HERE'

country = 'US'
main_url = 'https://govstatus.egov.com/kycovid19'
county_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/MapServer/0/query?where=1%3D1&text=&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=*&returnGeometry=false&returnTrueCurves=false&maxAllowableOffset=&geometryPrecision=&outSR=&having=&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&historicMoment=&returnDistinctValues=false&resultOffset=&resultRecordCount=&queryByDistance=&returnExtentOnly=false&datumTransformation=&parameterValues=&rangeValues=&quantizationParameters=&f=pjson'
state_death_gender_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=Deceased%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=Sex&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state_death_age_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=Deceased%3D%27Y%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=AgeGroup&orderByFields=AgeGroup%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state_cases_gender_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=Sex&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state_cases_age_url = 'https://kygisserver.ky.gov/arcgis/rest/services/WGS84WM_Services/Ky_Cnty_COVID19_Cases_WGS84WM/FeatureServer/1/query?f=json&where=AgeGroup%3C%3E%27Unconfirmed%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%27&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&groupByFieldsForStatistics=AgeGroup&orderByFields=AgeGroup%20asc&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectID%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D&outSR=102100&resultType=standard'
state = 'Kentucky'
columns = Headers.updated_site
columns.extend(['race', 'race_percentage', 'ethnicity', 'ethnicity_percentage'])
row_csv = []

# Main website
url = main_url
resolution = 'state'

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, "html5lib")

summary_data = soup.select('.number')
tested = summary_data[0].text.strip().replace(',', '')
cases = summary_data[1].text.strip().replace(',', '')
deaths = summary_data[2].text.strip().replace(',', '')
recovered = summary_data[3].text.strip().replace(',', '')

tables = soup.select('.table-covid')

# race
for tr in tables[0].select_one('tbody').select('tr'):
    data = tr.select('td')
    race = data[0].text
    race_percentage = data[1].text.replace('%', '')
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(html_text), access_time, nan,
        cases, updated, deaths, nan,
        recovered, tested, nan, nan,
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
        nan, nan,
        race, race_percentage, nan, nan])

# ethnicity
for tr in tables[1].select_one('tbody').select('tr'):
    data = tr.select('td')
    ethnicity = data[0].text
    ethnicity_percentage = data[1].text.replace('%', '')
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(html_text), access_time, nan,
        cases, updated, deaths, nan,
        recovered, tested, nan, nan,
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
        nan, nan,
        nan, nan, ethnicity, ethnicity_percentage])

# sex
for tr in tables[2].select_one('tbody').select('tr'):
    data = tr.select('td')
    sex = data[0].text
    sex_percentage = data[1].text.replace('%', '')
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(html_text), access_time, nan,
        cases, updated, deaths, nan,
        recovered, tested, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, sex, nan, sex_percentage,
        nan, nan,
        nan, nan, nan, nan])

# County-level data
url = county_url
resolution = 'county'

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

count_deaths = []
count_cases = []

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County']
    fips = attribute['FIPS']
    icu = attribute['ICU']
    hospitalized = attribute['Hospitalized']
    deaths = attribute['Deceased']
    cases = attribute['Confirmed']
    count_deaths.append(int(deaths))
    count_cases.append(int(cases))

    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, county,
        cases, updated, deaths, nan,
        nan, nan, hospitalized, nan,
        nan, nan, nan, nan, fips,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, icu, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan])

# Aggregated data
resolution = 'state'
row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        sum(count_cases), updated, sum(count_deaths), nan,
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
        nan, nan,
        nan, nan, nan, nan])

# State-level data - genders deaths
url = state_death_gender_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attribute = feature['attributes']
    deaths = attribute['value']
    sex = attribute['Sex']
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        nan, updated, deaths, nan,
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
        nan, sex, nan, nan,
        nan, nan,
        nan, nan, nan, nan])

# State-level data - age groups deaths
url = state_death_age_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attribute = feature['attributes']
    age_range = attribute['AgeGroup']
    age_deaths = attribute['value']
    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(raw_data), access_time, nan,
            nan, updated, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            age_range, nan, nan, age_deaths,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan])

# State-level data - genders cases
url = state_cases_gender_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attribute = feature['attributes']
    sex = attribute['Sex']
    sex_counts = attribute['value']

    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(raw_data), access_time, nan,
            nan, updated, nan, nan,
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
            nan, sex, sex_counts, nan,
            nan, nan,
            nan, nan, nan, nan])

# State-level data - age groups cases
url = state_cases_age_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attribute = feature['attributes']
    age_range = attribute['AgeGroup']
    age_cases = attribute['value']
    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(raw_data), access_time, nan,
            nan, updated, nan, nan,
            nan, nan, nan, nan,
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
            nan, nan,
            nan, nan, nan, nan])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=Headers.updated_site)
df.to_csv(file_name, index=False)
