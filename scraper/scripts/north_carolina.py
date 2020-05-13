#!/usr/bin/env python3

import requests
import datetime
import json
import os
from bs4 import BeautifulSoup
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

# convenience method to turn off huge data for manual review - use for HTML and JSON
def get_raw_data(raw_data):
    return str(raw_data)
    #return 'RAW_DATA_REMOVED_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    return dataframe.to_string()
    #return 'RAW_DATA_REMOVED_HERE'

country = 'US'
url = 'https://services.arcgis.com/iFBq2AW9XO0jYYF7/arcgis/rest/services/NCCovid19/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'North Carolina'
resolution = 'county'
columns = Headers.updated_site
columns.extend(['race', 'ethnicity', 'number_of_counties', 
    'race_cases', 'race_case_percentage', 
    'race_deaths', 'race_death_percentage',
    'ethnicity_cases', 'ethnicity_case_percentage', 
    'ethnicity_deaths', 'ethnicity_death_percentage',
    'congregate_living_setting', 'congregate_living_cases',
    'congregate_living_deaths', 'congregate_living_current_outbreaks',
    'ppe_type', 'ppe_ordered', 'ppe_received',
    'ppe_average_daily_requests', 'ppe_estimated_days_of_supplies_on_hand'])
row_csv = []

# County level
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
resolution = 'county'

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County']
    cases = attribute['Total']
    deaths = attribute['Deaths']

    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, county,
        cases, updated, deaths, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan,  nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan, # new values below this line
        nan, nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan, nan,
        nan, nan])

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
            each_df['updated'] = dict_info['updated']
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
        df_list['updated'] = dict_info['updated']
        df_columns = list(df_list.columns)
        for column in columns:
            if column not in df_columns:
                df_list[column] = nan
            else:
                pass
        final_df = df_list.reindex(columns=columns)
    return final_df

# source: https://stackoverflow.com/questions/23377533/python-beautifulsoup-parsing-table
def add_data_from_tr(row, data):
    cols = row.find_all('td')
    cols = [ele.text.strip() for ele in cols]
    data.append([ele for ele in cols if ele]) # Get rid of empty values

def remove_column_end_digits(df, columnsToReplace):
    '''
    Removes any digits which are at the end of a string, 
    which are usually subscripts or superscripts.

    :param df Dataframe to modify
    :param columnsToReplace Iterable of columns to operate on (e.g. [1,3])
    '''
    for columnNumber in columnsToReplace:
        df[df.columns[columnNumber]] = df[df.columns[columnNumber]].str.replace(r'\d+$', '')

def remove_column_nondigits(df, columnsToReplace):
    '''
    Remove any character in string that is not a digit or a decimal.

    :param df Dataframe to modify
    :param columnsToReplace Iterable of columns to operate on (e.g. [1,3])
    '''
    for columnNumber in columnsToReplace:
        try:
            df[df.columns[columnNumber]] = df[df.columns[columnNumber]].str.replace(r'[^\d.]', '')
        except AttributeError:
            # was read in as integer, float, or other non-string
            pass

url = "https://www.ncdhhs.gov/divisions/public-health/covid19/covid-19" \
      "-nc-case-count"
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, 'html.parser')

dict_info_html_tables = {'provider': 'state', 'country': country, "url": url,
                   "state": state, "resolution": "state",
                   "page": get_raw_data(html_text), "access_time": access_time,
                   "updated": updated}

tables = soup.find_all('tbody')
assert len(tables) == 9 # if this fails, the data could be incorrect

rows = tables[0].find_all('tr')
data = []
for row in rows:
    add_data_from_tr(row, data)
state_df = pd.DataFrame(data, columns=['cases', 'deaths', 'tested', 'hospitalized', 'number_of_counties'])
state_df = state_df.dropna()
remove_column_nondigits(state_df, [0, 1, 2, 3, 4])
state_df = fill_in_df(state_df, dict_info_html_tables, columns)

rows = tables[4].find_all('tr')
# find the row which only contains 'Ethnicity' - here is where we need to split up the two tables
table_breakpoint = 0
for index,row in enumerate(rows[1:], start=1):
    if row.find('td').text.strip() == 'Ethnicity':
        table_breakpoint = index
        break

# racial data from table
data = []
for row in rows[0:table_breakpoint]:
    add_data_from_tr(row, data)
race_df = pd.DataFrame(data, columns=['race', 'race_cases', 'race_case_percentage', 
    'race_deaths', 'race_death_percentage'])
race_df = race_df.dropna()
remove_column_end_digits(race_df, [0])
remove_column_nondigits(race_df, (1, 2, 3, 4))
race_df = fill_in_df(race_df, dict_info_html_tables, columns)

# ethnicity data from table
data = []
for row in rows[table_breakpoint+1:]:
    add_data_from_tr(row, data)
ethnicity_df = pd.DataFrame(data, columns=['ethnicity', 'ethnicity_cases', 'ethnicity_case_percentage', 
    'ethnicity_deaths', 'ethnicity_death_percentage'])
ethnicity_df = ethnicity_df.dropna()
remove_column_end_digits(ethnicity_df, [0])
remove_column_nondigits(ethnicity_df, (1, 2, 3, 4))
ethnicity_df = fill_in_df(ethnicity_df, dict_info_html_tables, columns)

# congregate living data - cases/deaths
rows = tables[5].find_all('tr')
data = []
for row in rows[:-1]:
    add_data_from_tr(row, data)
congregate_df_1 = pd.DataFrame(data, columns=['congregate_living_setting',
    'congregate_living_cases', 'congregate_living_deaths'])
remove_column_end_digits(congregate_df_1, [0])
remove_column_nondigits(congregate_df_1, (1, 2))
congregate_df_1 = fill_in_df(congregate_df_1, dict_info_html_tables, columns)

# congregate living data - number of outbreaks
rows = tables[6].find_all('tr')
data = []
for row in rows:
    add_data_from_tr(row, data)
congregate_df_2 = pd.DataFrame(data, columns=['congregate_living_setting', 
    'congregate_living_current_outbreaks', 'ongoing_outbreaks'])
remove_column_end_digits(congregate_df_2, [0])
# handle the third column 
congregate_df_tmp = congregate_df_2.copy()
congregate_df_2.drop('ongoing_outbreaks', axis=1, inplace=True)
remove_column_nondigits(congregate_df_2, [1])
congregate_df_2 = fill_in_df(congregate_df_2, dict_info_html_tables, columns)

# congregate living data - outbreaks by county
congregate_df_tmp.drop('congregate_living_current_outbreaks', axis=1, inplace=True)
resolution = 'county'
for row in congregate_df_tmp.itertuples():
    setting = getattr(row, congregate_df_tmp.columns[0])
    counties = getattr(row, congregate_df_tmp.columns[1]).split('; ')
    for item in counties:
        if ' ' in item:
            split = item.split(' ')
            county = split[0]
            outbreaks = ''.join(i for i in split[1] if i.isdigit())
        else:
            county = item
            outbreaks = 1
        row_csv.append([
            'state', country, state, nan,
            url, get_raw_data(html_text), access_time, county,
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
            nan, nan, # new values below this line
            nan, nan, nan,
            nan, nan,
            nan, nan,
            nan, nan,
            nan, nan,
            setting, nan,
            nan, outbreaks,
            nan, nan, nan,
            nan, nan])

# PPE - ordered/received
rows = tables[7].find_all('tr')
data = []
for row in rows:
    add_data_from_tr(row, data)
ppe_df_1 = pd.DataFrame(data, columns=['ppe_type', 
    'ppe_ordered', 'ppe_received'])
remove_column_end_digits(ppe_df_1, [0])
remove_column_nondigits(ppe_df_1, (1, 2))
ppe_df_1 = fill_in_df(ppe_df_1, dict_info_html_tables, columns)

# PPE - requests/supplies remaining
rows = tables[8].find_all('tr')
data = []
for row in rows:
    add_data_from_tr(row, data)
ppe_df_2 = pd.DataFrame(data, columns=['ppe_type', 
     'ppe_average_daily_requests', 'ppe_estimated_days_of_supplies_on_hand'])
remove_column_end_digits(ppe_df_2, [0])
remove_column_nondigits(ppe_df_2, (1, 2))
ppe_df_2 = fill_in_df(ppe_df_2, dict_info_html_tables, columns)

## Zipcode data

url = "https://services.arcgis.com/iFBq2AW9XO0jYYF7/ArcGIS/rest/services/" \
    "Covid19byZIPnew/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false" \
    "&returnExceededLimitFeatures=true&f=json"
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

resolution = 'zipcode'

for feature in raw_data['features']:
    attributes = feature['attributes']
    cases = attributes['Cases']
    deaths = attributes['Deaths']
    zipcode = attributes['ZIPCode']
    row_csv.append([
        'state', country, state, zipcode,
        url, get_raw_data(raw_data), access_time, nan,
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
        nan, nan, # new values below this line
        nan, nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan,
        nan, nan, nan,
        nan, nan])

### finished

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ','_') + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
all_df = pd.concat([df, state_df, race_df, ethnicity_df,
    congregate_df_1, congregate_df_2, ppe_df_1, ppe_df_2])
all_df.to_csv(file_name, index=False)
