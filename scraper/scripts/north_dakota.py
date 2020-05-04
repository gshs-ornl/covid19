#!/usr/bin/env python3

import requests
import datetime
import os
import json
from numpy import nan
import pandas as pd
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
        other, other_value])

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
        other, other_value])

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
        other, other_value])

### county level data - ignore the county-related charts on the main website! redundant compared to additional data

resolution='county'

# by county - total tests, positives, negatives, and recovered
# url = 'https://static.dwcdn.net/data/yuhr0.csv?v=1588308095287'
# by county - source of exposure
# url = 'https://static.dwcdn.net/data/49s5b.csv?v=1588308435970'
# additional datasets 
# url = 'https://static.dwcdn.net/data/yCjC4.csv?v=1588308904148'
# url = 'https://static.dwcdn.net/data/DlMVc.csv?v=1588308904591'
# url = 'https://static.dwcdn.net/data/Lgktn.csv?v=1588308904829'

### finished ###

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)