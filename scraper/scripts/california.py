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

row_csv = []

# convenience method to turn off huge data for manual review - use for HTML and JSON
def get_raw_data(raw_data):
    return str(raw_data)
    #return 'ALL_DATA_GOES_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    return dataframe.to_string()
    #return 'ALL_DATA_GOES_HERE'

country = 'US'
state = 'California'
columns = Headers.updated_site
# Additional values 
columns.extend(['race', 'race_age_cases', 'race_age_percent_cases', 
                'race_age_deaths', 'race_age_percent_deaths'])

resolution = 'state'
url = 'https://www.cdph.ca.gov/Programs/CID/DCDC/Pages/Immunization/ncov2019.aspx'
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

read_img = ReadImage(state_cases_url)
state_image_df = ReadImage.process(read_img)

# Parsing info for first image - state cases
#with pd.option_context('display.max_rows', None, 'display.max_columns', None):
    #print(state_image_df)

# values determined through iteration of the image rows
age_group_cases = []
gender_cases = []
cases = None
deaths = None
hospitalized = None
other_value_list = []

# constants
other_list = ('confirmed COVID-19 in ICU',
              'suspected COVID-19 hospitalized', 'suspected COVID-19 in ICU')
age_group_keys = ('0-17:', '18-49:', '50-64:', '65+:', 'Unknown/Missing:')
gender_keys = ('Female:', 'Male:', 'Unknown/Missing:')
# counter for number of times specific key appears
# The first result will be the missing gender, the second will be the missing age group
unknown_key_found = False

'''
Get the values which have two numbers separated by a '/' character. There should only be two values which match this.
'''
summary_pattern = re.compile(r'[\d,]+\/[\d,]+')
'''
This pattern lets us grab the total cases and the fatalities. It's important to check this pattern last in
the upcoming for loop due to the possibility of it otherwise catching other values.

At time of writing, cases are over '1,000' , which is a unique string that can be caught with logic. 
Integer values below 1000 and without commas are harder to check.
'''
cases_pattern = re.compile(r'[\d,]+,[\d]{3}')
'''
This pattern is only used in a very specific case. The deaths number is difficult to extract - the most consistent pattern
is that the lines will look like 'Suspected', 'COVID-19', and then the values we want before some nonsensical garbage. 
Sometimes the values can look like '1,982', sometimes '1' '9' '8' '2', sometimes '1' '88' '4', etc...
'''
deaths_pattern = re.compile(r'[\d,]+')

'''
The order of the loop is important. Do not check for the integer_pattern before checking
that the value is in the age_group_keys or gender_group_keys, or the death loop.
'''
xr = iter(range(len(state_image_df)))
for i in xr:
    string = str(state_image_df.iloc[i]['text']).strip()
    if string == 'Unknown/Missing:':
        # First result is a gender case, second result is an age case
        i += 1
        next(xr)
        if not unknown_key_found:
            gender_cases.append(int(state_image_df.iloc[i]['text'].replace(',', '')))
            unknown_key_found = True
        else:
            age_group_cases.append(int(state_image_df.iloc[i]['text'].replace(',', '')))
    elif string == 'Suspected':
        # We can manage to extract the deaths string here
        i += 2
        next(xr)
        next(xr)
        deathStr = ''
        while deaths_pattern.fullmatch(str(state_image_df.iloc[i]['text']).strip()):
            deathStr += str(state_image_df.iloc[i]['text']).strip()
            i += 1
            next(xr)
        deaths = int(deathStr.replace(',', ''))
    elif string in gender_keys:
        i += 1
        next(xr)
        gender_cases.append(int(state_image_df.iloc[i]['text'].replace(',', '')))
    elif string in age_group_keys:
        i += 1
        next(xr)
        age_group_cases.append(int(state_image_df.iloc[i]['text'].replace(',', '')))
    elif summary_pattern.fullmatch(string):
        elements = string.split('/')
        if len(other_value_list) == 0:
            hospitalized = int(elements[0].replace(',', ''))
            other_value_list.append(int(elements[1].replace(',', '')))
        else:
            other_value_list.append(int(elements[0].replace(',', '')))
            other_value_list.append(int(elements[1].replace(',', '')))
    elif cases_pattern.fullmatch(string):
        cases = int(string.replace(',', ''))

'''DEBUGGING
print(age_group_cases)
print(gender_cases)
print(cases)
print(deaths)
print(hospitalized)
print(other_value_list)
'''

if len(age_group_keys) == len(age_group_cases):
    for i in range(len(age_group_keys)):
        age_range = age_group_keys[i].strip(':')
        age_cases = age_group_cases[i]

        row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(html_text), access_time, nan,
            cases, updated, deaths, nan,
            nan, nan, hospitalized, nan,
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
else:
    print("There is not a 1:1 mapping of age_group_keys:age_group_values")

if len(gender_keys) == len(gender_cases):
    for i in range(len(gender_keys)):
        sex = gender_keys[i].strip(':')
        sex_counts = gender_cases[i]
        row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(html_text), access_time, nan,
            cases, updated, deaths, nan,
            nan, nan, hospitalized, nan,
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
else:
    print("There is not a 1:1 mapping of age_group_keys:age_group_values")

if len(other_list) == len(other_value_list):
    for idx in range(0, len(other_list)):
        other = other_list[idx]
        other_value = other_value_list[idx]
        row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(html_text), access_time, nan,
            cases, updated, deaths, nan,
            nan, nan, hospitalized, nan,
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

# function is only useful immediately after its declaration, don't call it after this
def calculate_race_data_external_to_table(elements):
    for element in elements:
        string = element.text.lower().replace("\xa0", " ")
        # all percentages will be the only things in parenthesis, i.e. (35%)
        if string.startswith('case'):
            int_regex = re.findall(r'[\d,]*[\d]', string)
            cases.append(int(int_regex[0].replace(',', '')))
            unknown_race_cases.append(int(int_regex[1].replace(',', '')))
            unknown_race_case_percentages.append(float(re.search(r'\(\s*(.*?)\s*\%', string).group(1)))
        elif string.startswith('death'):
            int_regex = re.findall(r'[\d,]*[\d]', string)
            deaths.append(int(int_regex[0].replace(',', '')))
            unknown_race_deaths.append(int(int_regex[1].replace(',', '')))
            unknown_race_death_percentages.append(float(re.search(r'\(\s*(.*?)\s*\%', string).group(1)))

calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(2)')
                                        .find('div').findAll('h4'))
calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(4)')
                                        .findAll('h4'))
# at time of writing, there have been no 0-17 deaths
if (len(deaths) != 2):
    deaths.append(0)
    unknown_race_deaths.append(0)
    unknown_race_death_percentages.append(0)

calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(6)')
                                        .findAll('h4'))
calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(8)')
                                        .findAll('h4'))
calculate_race_data_external_to_table(masterBodyElement.select_one('div:nth-of-type(9)')
                                        .find('div').findAll('h4'))

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

        race = str(table_data[0].text).strip(u'\u200b')
        race_age_cases = int(table_data[1].text.replace(',', '').strip(u'\u200b'))
        race_age_percent = float(table_data[2].text.replace(u'\u200b', ''))
        race_age_deaths = int(table_data[3].text.replace(',', '').strip(u'\u200b'))
        race_age_deaths_percent = float(table_data[4].text.replace(u'\u200b', ''))

        other_value = float(table_data[5].text.replace(u'\u200b', ''))
        row_csv.append([
                'state', country, state, nan,
                url, get_raw_data(html_text), access_time, nan,
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
        url, get_raw_data(html_text), access_time, nan,
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
cases = int(re.search(r'[\d,]*[\d]', elements[0].text).group(0).replace(',', ''))
deaths = int(re.search(r'[\d,]*[\d]', elements[1].text).group(0).replace(',', ''))
tested = int(re.search(r'[\d,]*[\d]', elements[2].text).group(0).replace(',', ''))

other_value = float(re.search(r'\(\s*(.*?)\s*\%', elements[0].text).group(1))

row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(html_text), access_time, nan,
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

other_value = float(re.search(r'\(\s*(.*?)\s*\%', elements[1].text).group(1))

row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(html_text), access_time, nan,
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

### data.chhs.ca.gov CSV file - by county
resolution = 'county'

url = 'https://data.chhs.ca.gov/dataset/6882c390-b2d7-4b9a-aefa-2068cee63e47/resource/6cd8d424-dfaa-4bdd-9410-a3d656e1176e/download/covid19data.csv'
# assumes default ordered dictionary (Python 3.7 or higher)
chhs_df_dict = {'Total Count Confirmed': pd.Int32Dtype(), 
                'Total Count Deaths': pd.Int32Dtype(),
                'COVID-19 Positive Patients': pd.Int32Dtype(),
                'Suspected COVID-19 Positive Patients': pd.Int32Dtype(),
                'ICU COVID-19 Positive Patients': pd.Int32Dtype(),
                'ICU COVID-19 Suspected Patients': pd.Int32Dtype()}
chhs_df_dict_list = list(chhs_df_dict)
chhs_df = pd.read_csv(url, dtype=chhs_df_dict)
access_time = datetime.datetime.utcnow()

raw_df = get_raw_dataframe(chhs_df)


# TODO - there may be a faster way to handle this i.e. https://stackoverflow.com/questions/16476924/how-to-iterate-over-rows-in-a-dataframe-in-pandas/55557758#55557758
for index,row in chhs_df.iterrows():
    county = row['County Name']
    updated = datetime.datetime.strptime(row['Most Recent Date'], "%m/%d/%Y")
    
    cases = row[chhs_df_dict_list[0]]
    deaths = row[chhs_df_dict_list[1]]
    hospitalized = row[chhs_df_dict_list[2]]

    other = chhs_df_dict_list[3]
    other_value = row[chhs_df_dict_list[3]]
    
    icu = row[chhs_df_dict_list[4]]

    row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            cases, updated, deaths, nan,
            nan, nan, hospitalized, nan,
            county, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, icu, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value, # additional values after this row
            nan, nan, nan, 
            nan, nan])
    
    other = chhs_df_dict_list[5]
    other_value = row[chhs_df_dict_list[5]]

    row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            cases, updated, deaths, nan,
            nan, nan, hospitalized, nan,
            county, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, icu, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value, # additional values after this row
            nan, nan, nan, 
            nan, nan])

### finished ###

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
