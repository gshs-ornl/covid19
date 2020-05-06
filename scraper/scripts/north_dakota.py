#!/usr/bin/env python3

import requests
import datetime
import os
import json
from numpy import nan
import pandas as pd
from io import StringIO
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

row_csv = []

# convenience method to turn off huge data for manual review - use for HTML/JSON
def get_html_text(html_text):
    return str(html_text)
    #return 'RAW_DATA_REMOVED_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    return dataframe.to_string()
    #return 'RAW_DATA_REMOVED_HERE'

country = 'US'
url = 'https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases'
state = 'North Dakota'
resolution = 'state'
columns = Headers.updated_site
columns.extend(['city', 'facility_name', 'facility_cases', 'last_report_date'])

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, "html5lib")

### state data ###

# header circles 
header_elements = soup.select('.circle')
cases = int(header_elements[0].select_one('h2').text)
negative = int(header_elements[1].select_one('h2').text)
tested = int(header_elements[2].select_one('h2').text)
recovered = int(header_elements[3].select_one('h2').text)
active = int(header_elements[4].select_one('h2').text)
hospitalized = int(header_elements[5].select_one('h2').text)
deaths = int(header_elements[6].select_one('h2').text)

# charts data
charts = soup.select('.charts-highchart')

### trending curve
chart1 = json.loads(charts[0].get('data-chart'))
other = 'New Cases'
# we need the current year because the chart values do not include the year
current_year_str = str(access_time.year)
# This is the only chart over time, so ignore values scraped from top
for i in range(len(chart1['xAxis']['categories'])) :
    localized_updated_str = chart1['xAxis']['categories'][i] + '-' + current_year_str
    localized_updated = datetime.datetime.strptime(localized_updated_str, '%d-%b-%Y')
    localized_cases = chart1['series'][0]['data'][i]
    localized_active = chart1['series'][1]['data'][i]
    other_value = chart1['series'][2]['data'][i]

    row_csv.append([
        'state', country, state, nan,
        url, get_html_text(html_text), access_time, nan,
        localized_cases, localized_updated, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        localized_active, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value, # additional values below this line
        nan, nan, nan, nan])

### cases by gender - pie chart, values can be used in other data rows
chart3 = json.loads(charts[2].get('data-chart'))
cases_male = chart3['series'][0]['data'][0]
cases_female = chart3['series'][0]['data'][1]

### source of exposure
chart2 = json.loads(charts[1].get('data-chart'))
for i in range(len(chart2['xAxis']['categories'])) :
    other = 'Number exposed from source: ' + chart2['xAxis']['categories'][i]
    other_value = chart2['series'][0]['data'][i]
    row_csv.append([
        'state', country, state, nan,
        url, get_html_text(html_text), access_time, nan,
        cases, updated, deaths, nan,
        recovered, tested, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        active, nan, nan,
        nan, nan, nan,
        resolution, nan, cases_male, cases_female,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value, # additional values below this line
        nan, nan, nan, nan])

### cases by age group AND hospitalized by age group - this works because age groups are same across both charts
chart4 = json.loads(charts[3].get('data-chart'))
chart5 = json.loads(charts[4].get('data-chart'))
other = 'recoveries by age_group'
for i in range(len(chart4['xAxis']['categories'])) :
    age_range = chart4['xAxis']['categories'][i]
    age_cases = chart4['series'][0]['data'][i]
    other_value = chart4['series'][1]['data'][i]
    age_deaths = chart4['series'][2]['data'][i]
    age_hospitalized = chart5['series'][1]['data'][i]
    row_csv.append([
        'state', country, state, nan,
        url, get_html_text(html_text), access_time, nan,
        cases, updated, deaths, nan,
        recovered, tested, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        active, nan, nan,
        nan, nan, nan,
        resolution, nan, cases_male, cases_female,
        nan, nan, nan, nan,
        age_range, age_cases, nan, age_deaths,
        age_hospitalized, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value, # additional values below this line
        nan, nan, nan, nan])

# deaths table
deaths_table = soup.select_one('tbody')
for table_row in deaths_table.select('tr')[:-1]:
    other = table_row.select('td')[0].select_one('strong').text
    other_value = table_row.select('td')[1].text
    row_csv.append([
        'state', country, state, nan,
        url, get_html_text(html_text), access_time, nan,
        cases, updated, deaths, nan,
        recovered, tested, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        active, nan, nan,
        nan, nan, nan,
        resolution, nan, cases_male, cases_female,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value, # additional values below this line
        nan, nan, nan, nan])

### county level data - ignore the county-related charts on the main website! redundant compared to additional data

'''
Notes about this county level data: 

- These websites were found by navigating to https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases and manually looking at the XHR requests.
- A request URL will look like this: https://static.dwcdn.net/data/yCjC4.csv?v=1588599421161
- It does not appear as though the 'v' query is relevant in any way - while the main website will automatically update this query and it is not easy to retrieve,
   the data appears to be updated regardless of the value of the 'v' query (or even if it is left off).
- The datawrapper iFrame ID on the main page for the above URL would look like 'datawrapper-chart-yCjC4'. 
   It could be possible to obtain all URL sources by selecting every single iframe on the page, getting the ID for each,
   then removing the 'datwrapper-chart-' string from the beginning of the ID.
'''

### by county - long term facility cases
url = 'https://static.dwcdn.net/data/DlMVc.csv'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
df = pd.read_csv(StringIO(response.text), parse_dates=['Last report date'])
facility_dict = {}

facility_cases = df.iloc[-1]['Case Count']
# get total number of cases before changing the resolution
row_csv.append([
    'state', country, state, nan,
    url, get_raw_dataframe(df), access_time, nan,
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
    nan, nan, # additional values below this line
    nan, 'All Facilities', facility_cases, nan])

# Change resolution to county for remainder of script
resolution='county'
# drop last row (which contains the total number of facility cases)
df.drop(df.tail(1).index,inplace=True)

for index,row in df.iterrows():
    city = row['City']
    county = row['County']
    facility_name = row['Facility Name']
    facility_cases = row['Case Count']
    last_report_date = row['Last report date']
    if county in facility_dict:
        facility_dict[county] += facility_cases
    else:
        facility_dict[county] = facility_cases
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_dataframe(df), access_time, county,
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
        city, facility_name, facility_cases, last_report_date])

# Total facility cases by county
for county in facility_dict:
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_dataframe(df), access_time, county,
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
        nan, nan, facility_dict[county], last_report_date])

### by county - total tests, positives, negatives, and recovered
url = 'https://static.dwcdn.net/data/yuhr0.csv'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
df = pd.read_csv(StringIO(response.text))

for index,row in df.iterrows():
    county = row['County']
    cases = row['Total Positive']
    negative = row['Total Negative']
    tested = row['Total Tested']
    recovered = row['Total Recovered']

    row_csv.append([
        'state', country, state, nan,
        url, get_raw_dataframe(df), access_time, county,
        cases, updated, nan, nan,
        recovered, tested, nan, negative,
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
        nan, nan, nan, nan])

### by county - source of exposure
url = 'https://static.dwcdn.net/data/49s5b.csv'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
df = pd.read_csv(StringIO(response.text))

for index,row in df.iterrows():
    county = row['County']

    # iterate through every column except the first, the 'County' column
    for column in df.columns[1:]:
        other = column
        other_value = row[other]
        row_csv.append([
            'state', country, state, nan,
            url, get_raw_dataframe(df), access_time, county,
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
            nan, nan, nan, nan])

### by county - rate per 100,000
url = 'https://static.dwcdn.net/data/Lgktn.csv'
# This data is also duplicated at 'https://static.dwcdn.net/data/yCjC4.csv' - used for the map instead of the table
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
df = pd.read_csv(StringIO(response.text))

for index,row in df.iterrows():
    county = row['County']
    cases = row['Cases']
    other_value = row['Rate Per 100000']
    recovered = row['Total Recovered']
    population = row['Population']

    other = 'Rate Per 100000'
    other_value = row['Rate Per 100000']
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_dataframe(df), access_time, county,
        cases, updated, nan, nan,
        recovered, nan, nan, nan,
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
        nan, nan, nan, nan])
    
    other = 'Population'
    other_value = row['Population']
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_dataframe(df), access_time, county,
        cases, updated, nan, nan,
        recovered, nan, nan, nan,
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
        nan, nan, nan, nan])

### finished ###

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ','_') + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)