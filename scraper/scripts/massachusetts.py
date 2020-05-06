#!/usr/bin/env python3

import datetime
import requests
import os
import glob
import shutil
import pandas as pd
import zipfile
from io import BytesIO
from numpy import nan
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

# convenience method to turn off huge data for manual review - use for HTML/JSON
def get_html_text(html_text):
    return str(html_text)
    #return 'RAW_DATA_REMOVED_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    return dataframe.to_string()
    #return 'RAW_DATA_REMOVED_HERE'

country = 'US'
state_url = 'https://www.mass.gov/info-details/covid-19-response-reporting'
state = 'Massachusetts'
columns = Headers.updated_site
columns.extend(['race'])
row_csv = []

### website
# State-level data
resolution = 'state'
url = state_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, 'html.parser')

data = []
for table in soup.find_all('table'):
    for row in table.find_all('tr'):
        cols = [ele.text.strip() for ele in row.find_all('td')]
        if cols:
            data.append(cols[0])

cases = data[0]
quarantine = data[1]
no_longer_monitored = data[2]
monitored = data[3]

row_csv.append([
        'state', country, state, nan,
        url, get_html_text(html_text), access_time, nan,
        cases, updated, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        monitored, no_longer_monitored, nan,
        nan, nan, quarantine,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan, # new values below this line
        nan])

### calculate latest zip URL
def get_zip_url(timestamp: datetime.datetime) -> str:
    url = 'https://www.mass.gov/doc/covid-19-raw-data-' + timestamp.strftime('%B-%-d-%Y').lower() + '/download'
    status = requests.head(url).status_code
    if status != 200:
        return get_zip_url(timestamp - datetime.timedelta(days=1))
    else:
        return url

'''
def fill_df(df_list, dict_info, columns):
    print(isinstance(df_list, list))
    df = []
    for each_df in df_list:
        for key in dict_info:
            each_df[key] = df_list[key]
        df_columns = list(each_df.columns)
        for column in columns:
            if column not in df_columns:
                each_df[column] = nan
        df.append(each_df.reindex(columns=columns))
    return pd.concat(df)
'''

# dump CSV files
# to view files added, manually review the data dictionaries included in the zip file
url = get_zip_url(datetime.datetime.utcnow())
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response) # used for some of the Excel sheets
zip_file = zipfile.ZipFile(BytesIO(response.content))
path = os.getenv("OUTPUT_DIR", "")
if not path.endswith('/'):
    path += '/'
csv_dir = path + '/mass_zips/'
# dump all the files out of memory and write to disk, for safety purposes
zip_file.extractall(csv_dir)

### Age Means CSV
df = pd.read_csv(csv_dir + 'Age Means.csv', parse_dates=['Date'])
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'mean_overall_age', 'mean_hospitalized_age', 'mean_death_age']
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])

    for i in range(1, 4):
        other = df.columns[i]
        other_value = getattr(row, other)
        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
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
            other, other_value, # additional values below here
            nan])

### Age CSV
df = pd.read_csv(csv_dir + 'Age.csv', parse_dates=['Date'], 
                dtype={'Cases': pd.Int32Dtype(), 'Hospitalized': pd.Int32Dtype(),
                'Deaths': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
'''
df_dict = {'provider': 'state', 'country': country,
                          "state": state, "url": url,
                          "resolution": resolution, "page": get_raw_dataframe(df), 
                          "access_time": access_time}
'''
df.columns = ['updated', 'age_range', 'age_cases', 'age_hospitalized', 'age_deaths']
#df_1 = fill_df(df, df_dict, columns)
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    age_range = getattr(row, df.columns[1])
    age_cases = getattr(row, df.columns[2])
    age_hospitalized = getattr(row, df.columns[3])
    age_deaths = getattr(row, df.columns[4])
    row_csv.append([
        'state', country, state, nan,
        url, raw_df, access_time, nan,
        nan, localized_updated, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age_range, age_cases, nan, age_deaths,
        age_hospitalized, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan, # new values below this line
        nan])

### Cases CSV
# two columns - Cases and Positive - appear to be duplicates
df = pd.read_csv(csv_dir + 'Cases.csv', parse_dates=['Date'], 
                dtype={'Positive': pd.Int32Dtype(), 'Presumptive +': pd.Int32Dtype(),
                'Cases': pd.Int32Dtype(), 'New': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
#df_dict['page'] = get_raw_dataframe(df)
df.drop('Positive', axis=1, inplace=True)
df.columns = ['updated', 'presumptive', 'cases', 'other_value']
other = 'New Cases'
#df['other'] = 'New Cases'
#df_2 = fill_df(df, df_dict, columns)
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    presumptive = getattr(row, df.columns[1])
    cases = getattr(row, df.columns[2])
    other_value = getattr(row, df.columns[3])
    
    row_csv.append([
        'state', country, state, nan,
        url, raw_df, access_time, nan,
        cases, localized_updated, nan, presumptive,
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
        other, other_value, # additional values below here
        nan])

### Date of Death CSV
# deaths = deaths occurred (should be other_value)
df = pd.read_csv(csv_dir + 'DateofDeath.csv', parse_dates=['Date of Death'], 
                dtype={'New Deaths': pd.Int32Dtype(), 'Running Total': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'new_deaths_occurred', 'total_deaths_occurred']
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])

    for i in range(1, 3):
        other = df.columns[i]
        other_value = getattr(row, other)
        
        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
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
            other, other_value, # additional values below here
            nan])

### Death Pies CSV
df = pd.read_csv(csv_dir + 'Death Pies.csv', parse_dates=['Date'], 
                dtype={'Deaths': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'category', 'response', 'deaths']
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    category = getattr(row, df.columns[1])
    localized_response = getattr(row, df.columns[2])
    other_value = getattr(row, df.columns[3])
    
    if (category.lower() == 'sex'):
        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
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
            nan, localized_response, nan, nan,
            'sex_deaths', other_value, # new values below this line
            nan])
    elif (category.lower().startswith('hosp')):
        if localized_response.lower() == 'yes':
            other = 'hospitalized_deaths'
        elif localized_response.lower() == 'no':
            other = 'not_hospitalized_deaths'
        else:
            other = 'deaths_with_unknown_hospitalization_status'
        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
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
            other, other_value, # new values below this line
            nan])
    elif (category.lower().startswith('preexist')):
        if localized_response.lower() == 'yes':
            other = 'deaths_with_preexisting_conditions'
        elif localized_response.lower() == 'no':
            other = 'deaths_with_no_preexisting_conditions'
        else:
            other = 'deaths_with_unknown_preexisting_conditions'
        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
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
            other, other_value, # new values below this line
            nan])
    else:
        print('A new category in deathPies.csv has been detected. This script needs to be updated.')

# DeathsReported CSV
# deaths = deaths reported
df = pd.read_csv(csv_dir + 'DateofDeath.csv', parse_dates=['Date of Death'], 
                dtype={'Deaths': pd.Int32Dtype(), 'New': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'new_deaths', 'deaths']
other = 'new_deaths_reported'
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    other_value = getattr(row, df.columns[1])
    deaths = getattr(row, df.columns[2])
    
    row_csv.append([
        'state', country, state, nan,
        url, raw_df, access_time, nan,
        nan, localized_updated, deaths, nan,
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
        other, other_value, # additional values below here
        nan])

# Hospitalization from Hospitals CSV
df = pd.read_csv(csv_dir + 'Hospitalization from Hospitals.csv', parse_dates=['Date'], 
                dtype={'Total number of COVID patients in hospital today': pd.Int32Dtype(), 
                'Net new hospitalizations': pd.Int32Dtype(), 'ICU': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'hospitalized', 'new_hospitalized', 'five_day_net_new_hospitalization_average', 'icu']
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    hospitalized = getattr(row, df.columns[1])
    icu = getattr(row, df.columns[4])
    
    for i in range(2, 4):
        other = df.columns[i]
        other_value = getattr(row, other)

        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
            nan, nan, hospitalized, nan,
            nan, nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            nan, nan, nan,
            resolution, icu, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan, nan,
            nan, nan, nan,
            nan, nan,
            nan, nan, nan, nan,
            other, other_value, # additional values below here
            nan])

# LTC Facilities CSV
df = pd.read_csv(csv_dir + 'LTC Facilities.csv', parse_dates=['date'], 
                dtype={'Cases in Residents/Healthcare Workers of LTCFs': pd.Int32Dtype(), 
                'facilities': pd.Int32Dtype(), 'Deaths Reported in LTCFs': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'cases_in_residents_and_workers_of_ltc_facilities', 'facilities_reporting_cases', 'facility_deaths']
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    
    for i in range(1, 4):
        other = df.columns[i]
        other_value = getattr(row, other)

        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
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
            other, other_value, # additional values below here
            nan])

# Race/Ethnicity CSV
df = pd.read_csv(csv_dir + 'RaceEthnicity.csv', parse_dates=['Date'], 
                dtype={'All Cases': pd.Int32Dtype(), 
                'Ever Hospitaltized': pd.Int32Dtype(), 'Deaths': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'race', 'race_cases', 'race_ever_hospitalized', 'race_deaths']
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    race = getattr(row, df.columns[1])
    
    for i in range(2, 5):
        other = df.columns[i]
        other_value = getattr(row, other)

        row_csv.append([
            'state', country, state, nan,
            url, raw_df, access_time, nan,
            nan, localized_updated, nan, nan,
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
            other, other_value, # additional values below here
            race])

# Sex CSV
df = pd.read_csv(csv_dir + 'Sex.csv', parse_dates=['Date'], 
                dtype={'Male': pd.Int32Dtype(), 
                'Female': pd.Int32Dtype(), 'Unknown': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'male', 'female', 'unknown_gender']
other = df.columns[3]
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    cases_male = getattr(row, df.columns[1])
    cases_female = getattr(row, df.columns[2])
    other_value = getattr(row, df.columns[3])

    row_csv.append([
        'state', country, state, nan,
        url, raw_df, access_time, nan,
        nan, localized_updated, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, cases_male, cases_female,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        other, other_value, # additional values below here
        nan])

# Testing CSV
df = pd.read_csv(csv_dir + 'Testing2.csv', parse_dates=['Date'], 
                dtype={'Total': pd.Int32Dtype(), 
                'New': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'tested', 'new_tested']
other = df.columns[2]
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    tested = getattr(row, df.columns[1])
    other_value = getattr(row, df.columns[2])

    row_csv.append([
        'state', country, state, nan,
        url, raw_df, access_time, nan,
        nan, localized_updated, nan, nan,
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
        other, other_value, # additional values below here
        nan])

# County CSV
resolution = 'county'
df = pd.read_csv(csv_dir + 'County.csv', parse_dates=['Date'], 
                dtype={'Count': pd.Int32Dtype(), 
                'Deaths': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['updated', 'county', 'cases', 'deaths']
for row in df.itertuples():
    localized_updated = getattr(row, df.columns[0])
    county = getattr(row, df.columns[1])
    cases = getattr(row, df.columns[2])
    deaths = getattr(row, df.columns[3])

    row_csv.append([
        'state', country, state, nan,
        url, raw_df, access_time, county,
        cases, localized_updated, deaths, nan,
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
        nan, nan, # additional values below here
        nan])


### EXCEL FILES ###
excel_file = glob.glob(csv_dir + '*.xlsx')[0]

# Excel - Regional bed availability
resolution = 'region'
df = pd.read_excel(excel_file, sheet_name=0, 
                    dtype={'Occupied ICU': pd.Int32Dtype(), 'Occupied Medical/Surgical': pd.Int32Dtype(),
                    'Occupied Alternate Medical Site': pd.Int32Dtype(), 'Available ICU': pd.Int32Dtype(),
                    'Available Medical/Surgical': pd.Int32Dtype(), 'Available Alternate Medical Site': pd.Int32Dtype()})
raw_df = get_raw_dataframe(df)
df.columns = ['region', 'regional_bed_availability', 'occupied_icu', 'occupied_medical_surgical', 'occupied_alternate_medical', 
                'available_medical_surgical', 'available_alternate_medical']
for row in df.itertuples():
    region = getattr(row, df.columns[0])
    for i in range(1, 7):
        other = df.columns[i]
        other_value = getattr(row, other)

        row_csv.append([
            'state', country, state, region,
            url, raw_df, access_time, nan,
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
            other, other_value, # additional values below here
            nan])

'''
resolution = 'state'
# Excel - Hospital COVID census
df = pd.read_excel(excel_file, sheet_name=1)
raw_df = get_raw_dataframe(df)
print(df.to_string())

# Excel - nursing homes
df = pd.read_excel(excel_file, sheet_name=2)
raw_df = get_raw_dataframe(df)
print(df.to_string())

# Excel - assisted living residences
df = pd.read_excel(excel_file, sheet_name=3)
raw_df = get_raw_dataframe(df)
print(df.to_string())

# Excel - nursing home testing
df = pd.read_excel(excel_file, sheet_name=4)
raw_df = get_raw_dataframe(df)
print(df.to_string())

# Excel - PPE-Summary
df = pd.read_excel(excel_file, sheet_name=5)
raw_df = get_raw_dataframe(df)
print(df.to_string())

# Excel - PPE - Regional
resolution = 'region'
df = pd.read_excel(excel_file, sheet_name=6)
raw_df = get_raw_dataframe(df)
print(df.to_string())
'''

### finished ###

# remove unzipped directory
shutil.rmtree(csv_dir)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
