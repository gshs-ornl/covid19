#!/usr/bin/env python3

import requests
import datetime
import os
import re
from numpy import nan
import pandas as pd
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers
from cvpy.ocr import ReadImage
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
url = 'https://www.cdph.ca.gov/Programs/CID/DCDC/Pages/Immunization/ncov2019.aspx'
state = 'California'
resolution = 'state'
columns = Headers.updated_site
# Additional values 
columns.extend(['race', 'race_age_cases', 'race_age_percent_cases', 
                'race_age_deaths', 'race_age_percent_deaths'])

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, "html5lib")

placeholder_url = 'https://www.cdph.ca.gov/Programs'
imgs = soup.find_all('img')
for img in imgs:
    img_src = img['src']
    if 'CA_COVID-19' in img_src:
        state_cases_url = img_src.replace('/Programs', placeholder_url)
        break

row_csv = []

read_img = ReadImage(state_cases_url)
state_image_df = ReadImage.process(read_img)

# Parsing info for first image - state cases
age_group_row_nums = [49, 57, 65, 70, 75]
gender_row_nums = [52, 60, 109]
#with pd.option_context('display.max_rows', None, 'display.max_columns', None):
    #print(state_image_df)
confirmed_hospitalized_info = state_image_df.iloc[129]['text'].split('/')
suspected_hospitalized_info = state_image_df.iloc[130]['text'].split('/')

other_list = ['confirmed COVID-19 in ICU',
              'suspected COVID-19 hospitalized', 'suspected COVID-19 in ICU']
other_value_list = [confirmed_hospitalized_info[1],
               suspected_hospitalized_info[0], suspected_hospitalized_info[1]]

cases = int((state_image_df.iloc[30]['text']).replace(',', ''))
hospitalized = confirmed_hospitalized_info[0]
# WARNING: this is unstable, as this value can easily be read into multiple lines
deaths = int(''.join((state_image_df.iloc[124]['text'], state_image_df.iloc[125]['text'], state_image_df.iloc[126]['text'])))

for age_group_row_num in age_group_row_nums:
    age_range = state_image_df.iloc[age_group_row_num]['text'].replace(':', '')
    age_cases = int(
        state_image_df.iloc[age_group_row_num + 1]['text'].replace(',', ''))

    row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
        cases, updated, deaths, nan,
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
        nan, nan, # additional values after this row
        nan, nan, nan, 
        nan, nan])

for gender_row_num in gender_row_nums:
    sex = state_image_df.iloc[gender_row_num]['text'].replace(':', '')
    sex_counts = int(
        state_image_df.iloc[gender_row_num + 1]['text'].replace(',', ''))
    row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
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
        nan, sex, sex_counts, nan,
        nan, nan, # additional values after this row
        nan, nan, nan, 
        nan, nan])

if len(other_list) == len(other_value_list):
    for idx in range(0, len(other_list)):
        other = other_list[idx]
        other_value = other_value_list[idx]
        row_csv.append([
            'state', country, state, nan,
            url, str(html_text), access_time, nan,
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
            other, other_value, # additional values after this row
            nan, nan, nan, 
            nan, nan])
else:
    print("The lengths for other keys and values are not equal")

### get racial data ###

url = 'https://www.cdph.ca.gov/Programs/CID/DCDC/Pages/COVID-19/Race-Ethnicity.aspx'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
html_text = response.text
soup = BeautifulSoup(html_text, "html5lib")

'''
Begin unstable scraping

The FIRST table and the LAST table has the additional data inside an HTML sibling of the table
The other tables all have the additional data inside containers which are siblings of the PARENT of the table...
There is some additional data after each table, but this is stupidly annoying to get to due to inconsistent HTML layout
'''

# Everything relevant will be under this header
masterBodyElement = soup.select_one('#WebPartWPQ4').find('div')

# unfortunately, the time at the very bottom of the page is server-side generated, and not accessible in the raw html
# that value can also be ahead of the one we are scraping
updatedElement = masterBodyElement.find('div').select_one('h3:nth-of-type(2)').findAll('span')
updated = updatedElement[0].text + updatedElement[1].text
updated = datetime.datetime.strptime(updated.replace(u'\u200b', ''), '%B %d, %Y')

cases = []
unknown_race_cases = []
unknown_race_case_percentages = []
deaths = []
unknown_race_deaths = []
unknown_race_death_percentages = []

def calculate_race_data_external_to_table(elements, cases, unknown_race_cases, deaths, unknown_race_deaths):
    for element in elements:
        string = element.text.lower().replace("\xa0", " ")
        # all percentages will be the only things in parenthesis, i.e. (35%)
        if string.startswith('case'):
            unknown_race_case_percentages.append(float(re.search(r'\((.*?)\%', string).group(1)))
            cases.append(int(re.search(r'([\d,]+)', string).group(1).replace(',', '')))
            unknown_race_cases.append(int(re.findall(r'([\d,]+)', string)[1].replace(',', '')))
        elif string.startswith('death'):
            unknown_race_death_percentages.append(float(re.search(r'\((.*?)\%', string).group(1)))
            deaths.append(int(re.search(r'([\d,]+)', string).group(1).replace(',', '')))
            unknown_race_deaths.append(int(re.findall(r'([\d,]+)', string)[1].replace(',', '')))

calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(2)').find('div').findAll('h4'),
                                        cases, unknown_race_cases, deaths, unknown_race_deaths)
calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(4)').findAll('h4'),
                                        cases, unknown_race_cases, deaths, unknown_race_deaths)
# at time of writing, there have been no 0-17 deaths
if (len(deaths) != 2):
    deaths.append(0)
    unknown_race_deaths.append(0)
    unknown_race_death_percentages.append(0)

calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(6)').findAll('h4'),
                                        cases, unknown_race_cases, deaths, unknown_race_deaths)
calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(8)').findAll('h4'),
                                        cases, unknown_race_cases, deaths, unknown_race_deaths)
calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(9)').find('div').findAll('h4'),
                                        cases, unknown_race_cases, deaths, unknown_race_deaths)

''' End less stable scraping '''

# this tuple should represent each table from the URL - it DOES assume that the age groups and the table orderings remain constant
age_ranges = ('all age groups', '0-17', '18-49', '50-64', '65+')
tables = soup.findAll('table')

for tableIndex,table in enumerate(tables):
    age_range = age_ranges[tableIndex]
    table_rows = table.findAll('tr')
    # Skip the first row - it only has the column headers
    for table_row in table_rows[1:]:
        table_data = table_row.findAll('td')

        race = table_data[0].text
        race_age_cases = int(table_data[1].text.replace(',', '').strip(u'\u200b'))
        race_age_percent = float(table_data[2].text.strip(u'\u200b'))
        race_age_deaths = int(table_data[3].text.replace(',', '').strip(u'\u200b'))
        race_age_deaths_percent = float(table_data[4].text.strip(u'\u200b'))

        other_value = float(table_data[5].text.strip(u'\u200b'))
        row_csv.append([
                'state', country, state, nan,
                url, str(html_text), access_time, nan,
                cases[tableIndex], updated, deaths[tableIndex], nan,
                nan, nan, nan, nan,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                resolution, nan, nan, nan,
                nan, nan, nan, nan,
                age_range, nan, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                'Percent CA population', other_value, # additional values after this row
                race, race_age_cases, race_age_percent, 
                race_age_deaths, race_age_deaths_percent])

    # add unknown race case values here
    row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
        cases[tableIndex], updated, deaths[tableIndex], nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age_range, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan, # additional values after this row
        'unknown', unknown_race_cases[tableIndex], unknown_race_case_percentages[tableIndex], 
        unknown_race_deaths[tableIndex], unknown_race_death_percentages[tableIndex]])

### dedicated COVID website ###
url = 'https://covid19.ca.gov/'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
# There is a parseable last-modified HTML value on this website, but it is in PST. 
# When last tested, the HTML value for this was two minutes behind the HTTP header
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, "html5lib")

elements = soup.select(".h3") # there are exactly 3 elements with this class
cases = int(re.search(r'([\d,]+)', elements[0].text).group(1).replace(',', ''))
deaths = int(re.search(r'([\d,]+)', elements[1].text).group(1).replace(',', ''))
tested = int(re.search(r'([\d,]+)', elements[2].text).group(1).replace(',', ''))

other_value = float(re.search(r'\((.*?)\%', elements[0].text).group(1))

row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
        cases, updated, deaths, nan,
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
        'case_percentage_increase', other_value, # additional values after this row
        nan, nan, nan, 
        nan, nan])

other_value = float(re.search(r'\((.*?)\%', elements[1].text).group(1))

row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
        cases, updated, deaths, nan,
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
        'death_percentage_increase', other_value, # additional values after this row
        nan, nan, nan, 
        nan, nan])

### finished ###

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
