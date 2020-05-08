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

# convenience method to turn off huge data for manual review - use for HTML and JSON
def get_raw_data(raw_data):
    #return str(raw_data)
    return 'RAW_DATA_REMOVED_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    #return dataframe.to_string()
    return 'RAW_DATA_REMOVED_HERE'

country = 'US'
url = 'https://services.arcgis.com/qnjIrwR8z5Izc0ij/ArcGIS/rest/services/COVID_Cases_Production_View/FeatureServer/0/query?f=json&where=Total%20%3C%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=NewCases%20desc%2CNAMELABEL%20asc&resultOffset=0&resultRecordCount=56&cacheHint=true'
state_url_tested = 'https://services.arcgis.com/qnjIrwR8z5Izc0ij/ArcGIS/rest/services/COVID_Cases_Production_View/FeatureServer/1/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Total_Tests_Completed%20desc&resultOffset=0&resultRecordCount=1&cacheHint=true'
state = 'Montana'

columns = Headers.updated_site
columns.extend(['race', 'ethnicity_specified'])
row_csv = []

# County level
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
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
            url, get_raw_data(raw_data), access_time, county,
            cases, updated, deaths, nan,
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
            nan, nan, # additional values below this line
            nan, nan])

    for gender in ['Female', 'Male']:
        sex = gender
        if gender == 'Female':
            sex_count = sum(female_raw)
        elif gender == 'Male':
            sex_count = sum(male_raw)

        row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(raw_data), access_time, county,
            cases, updated, deaths, nan,
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
            nan, nan, # additional values below this line
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
                url, get_raw_data(raw_data), access_time, nan,
                cases, updated, deaths, nan,
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
                nan, nan, # additional values below this line
                nan, nan])


for gender in ['Female', 'Male']:
    sex = gender
    if gender == 'Female':
        sex_count = sum(state_female_raw)
    elif gender == 'Male':
        sex_count = sum(state_male_raw)

    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        cases, updated, deaths, nan,
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
        nan, nan, # additional values below this line
        nan, nan])

with open(state+'county_data.json', 'w') as f:
    json.dump(raw_data, f)

# State level - tests
response = requests.get(state_url_tested)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
tested = raw_data['features'][0]['attributes']['Total_Tests_Completed']

row_csv.append([
        'state', country, state, nan,
        state_url_tested, get_raw_data(raw_data), access_time, nan,
        nan, updated, nan, nan,
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
        nan, nan, # additional values below this line
        nan, nan])

# EOC - state - number open
url = 'https://services.arcgis.com/qnjIrwR8z5Izc0ij/arcgis/rest/services/Join_EOC_Status/FeatureServer/0/query?f=json&where=(county_eoc_activation_status%3D%27open%27%20OR%20county_eoc_activation_status%3D%27partial%27)&returnGeometry=false&outFields=*&outStatistics=%5B%7B%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22%7D%5D'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
other = 'EOC_reported_open'
other_value = raw_data['features'][0]['attributes']['value']
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
        nan, nan, nan, nan,
        other, other_value, # additional values below this line
        nan, nan])

# EOC - state - number of declarations made
url = 'https://services.arcgis.com/qnjIrwR8z5Izc0ij/arcgis/rest/services/Join_EOC_Status/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&outFields=*&groupByFieldsForStatistics=county_declaration_made&outStatistics=[{%22statisticType%22%3A%22count%22%2C%22onStatisticField%22%3A%22ObjectId%22%2C%22outStatisticFieldName%22%3A%22value%22}]'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
for feature in raw_data['features']:
    other = 'Declaration made: ' + feature['attributes']['county_declaration_made']
    other_value = feature['attributes']['value']
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
        nan, nan, nan, nan,
        other, other_value, # additional values below this line
        nan, nan])

# EOC - county data
resolution = 'county'
url = 'https://services.arcgis.com/qnjIrwR8z5Izc0ij/arcgis/rest/services/Join_EOC_Status/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&outFields=*&orderByFields=NAME%20asc'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
# while there is a LAST_UPDAT property for each county, those can point to years such as 2006
updated = determine_updated_timestep(response)
raw_data = response.json()
for feature in raw_data['features']:
    attributes = feature['attributes']
    county = attributes['NAME'].capitalize()
    fips = attributes['CTYFIPS']

    for other in ['county_eoc_activation_status', 'incident_command_status', 'county_declaration_made']:
        other_value = attributes[other]
        row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(raw_data), access_time, county,
            nan, updated, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan, fips,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value, # additional values below this line
            nan, nan])

### web table
url = 'https://dphhs.mt.gov/publichealth/cdepi/diseases/coronavirusmt/demographics'
'''
# FIXME getting 'DH_KEY_TOO_SMALL' error without the below code
Worth noting is that openssl in the Docker container mandates TLSv1.2 or higher,
and none of the cipher suites in SSLLabs match up with the cipher suites specified
by urllib3. (The server only seems to use AES cipher suites.)

Some of the additional certificates expire May 30, 2020, so check back then to see
if this is still required.
'''
requests.packages.urllib3.util.ssl_.DEFAULT_CIPHERS += 'HIGH:!DH:!aNULL'
try:
    requests.packages.urllib3.contrib.pyopenssl.DEFAULT_SSL_CIPHER_LIST += 'HIGH:!DH:!aNULL'
except AttributeError:
    # no pyopenssl support used / needed / available
    pass
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, "html5lib")
#soup.prettify(formatter=lambda s: s.replace(u'\xa0', ' '))

tables = soup.select('tbody')

# get rid of unicode before extracting soup text
def clean_unicode(soup) -> str:
    return str(soup.text).replace('\xa0', ' ')

# general state data
resolution = 'state'
cases = int(clean_unicode(tables[0].select('tr')[0].select('td')[1]))
deaths = int(clean_unicode(tables[0].select('tr')[1].select('td')[1]))
hospitalized = int(clean_unicode(tables[6].select('tr')[0].select('td')[1]).split(' ')[0])
quarantined = int(clean_unicode(tables[6].select('tr')[2].select('td')[1]).split(' ')[0])
recovered = int(clean_unicode(tables[6].select('tr')[3].select('td')[1]).split(' ')[0])
cases_female = int(clean_unicode(tables[4].select('tr')[0].select('td')[1]).split(' ')[0])
cases_male = int(clean_unicode(tables[4].select('tr')[1].select('td')[1]).split(' ')[0])
active = hospitalized + quarantined

# hospitalization status
for table_row in tables[2].select('tr')[:-1]:
    other = clean_unicode(table_row.select('td')[0])
    other_value = int(clean_unicode(table_row.select('td')[1]).split(' ')[0])
    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(html_text), access_time, nan,
            cases, updated, deaths, nan,
            recovered, nan, hospitalized, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            active, nan, quarantined,
            nan, nan, nan,
            resolution, nan, cases_male, cases_female,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value, # additional values below this line
            nan, nan])

# age group
for table_row in tables[3].select('tr')[:-1]:
    age_range = clean_unicode(table_row.select('td')[0]).split(' ')[0]
    age_stats = clean_unicode(table_row.select('td')[1]).split(' ')
    if '<' in (age_stats[1]):
        age_percent = 0
    else:
        age_percent = int(''.join(i for i in age_stats[1] if i.isdigit()))
    age_cases = int(age_stats[0])
    row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(html_text), access_time, nan,
            cases, updated, deaths, nan,
            recovered, nan, hospitalized, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            active, nan, quarantined,
            nan, nan, nan,
            resolution, nan, cases_male, cases_female,
            nan, nan, nan, nan,
            age_range, age_cases, age_percent, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            nan, nan, # additional values below this line
            nan, nan])

# race/ethnicity
race_not_ethnicity_flag = True # true = race, false = ethnicity
for table_row in tables[5].select('tr')[:-1]:
    identifier = clean_unicode(table_row.select('td')[0])
    race_stats = clean_unicode(table_row.select('td')[1]).split(' ')
    # skip total rows
    if len(race_stats) < 2:
        continue
    # row was parsed as ['', ''] - this row separates race and ethnicity
    if race_stats[0] == '':
        race_not_ethnicity_flag = False
        continue

    if (race_not_ethnicity_flag == True):
        other = 'race_cases'
        other_value = int(race_stats[0])
        row_csv.append([
                'state', country, state, nan,
                url, get_raw_data(html_text), access_time, nan,
                cases, updated, deaths, nan,
                recovered, nan, hospitalized, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                active, nan, quarantined,
                nan, nan, nan,
                resolution, nan, cases_male, cases_female,
                nan, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                other, other_value, # additional values below this line
                identifier, nan])
        
        other = 'race_percent'
        if '<' in race_stats[1]:
            other_value = 0
        else:
            other_value = int(''.join(i for i in race_stats[1] if i.isdigit()))
        row_csv.append([
                'state', country, state, nan,
                url, get_raw_data(html_text), access_time, nan,
                cases, updated, deaths, nan,
                recovered, nan, hospitalized, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                active, nan, quarantined,
                nan, nan, nan,
                resolution, nan, cases_male, cases_female,
                nan, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                other, other_value, # additional values below this line
                identifier, nan])
    else:
        other = 'ethnicity_cases'
        other_value = int(race_stats[0])
        row_csv.append([
                'state', country, state, nan,
                url, get_raw_data(html_text), access_time, nan,
                cases, updated, deaths, nan,
                recovered, nan, hospitalized, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                active, nan, quarantined,
                nan, nan, nan,
                resolution, nan, cases_male, cases_female,
                nan, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                other, other_value, # additional values below this line
                nan, identifier])
        
        other = 'ethnicity_percent'
        if '<' in race_stats[1]:
            other_value = 0
        else:
            other_value = int(''.join(i for i in race_stats[1] if i.isdigit()))
        row_csv.append([
                'state', country, state, nan,
                url, get_raw_data(html_text), access_time, nan,
                cases, updated, deaths, nan,
                recovered, nan, hospitalized, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                active, nan, quarantined,
                nan, nan, nan,
                resolution, nan, cases_male, cases_female,
                nan, nan, nan, nan,
                nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                other, other_value, # additional values below this line
                nan, identifier])

# county table
resolution = 'county'
other = 'community_transmission'
for table_row in tables[1].select('tr')[:-1]:
    table_data = table_row.findAll('td')

    county = clean_unicode(table_data[0])
    cases = int(clean_unicode(table_data[1]))
    deaths = clean_unicode(table_data[2])
    if (deaths.isspace()):
        deaths = 0
    else:
        deaths = int(deaths)
    other_value = clean_unicode(table_data[3])
    if (other_value.isspace()):
        other_value = 'No'

    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(html_text), access_time, county,
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
        other, other_value, # additional values below this line
        nan, nan])

### finished

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
