#!/usr/bin/env python3

import datetime
import requests
import os
import pandas as pd
from io import BytesIO
from numpy import nan
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

# convenience method to turn off huge data for manual review - use for HTML/JSON
def get_raw_data(html_text):
    return str(html_text)
    #return 'RAW_DATA_REMOVED_HERE'

# convenience method to turn off huge data for manual review - use for dataframes
def get_raw_dataframe(dataframe: pd.DataFrame):
    return dataframe.to_string()
    #return 'RAW_DATA_REMOVED_HERE'

# handle instances where '0' is stored as 'null'
def read_number(value):
    try:
        int(value)
        return value
    except TypeError:
        # 0 values are stored as 'null'
        return '0'

# constants for sanity check
URL_DICT = 'url'
ACCESS_TIME_DICT = 'access_time'
UPDATED_DICT = 'updated'
RAW_DATA_DICT = 'raw_data'
FEATURES = 'features'
ATTRIBUTES = 'attributes'

def get_arcgis_data(base_query_url, lower_bound, upper_bound):
    '''
    Most ArcGIS servers have a request limit of a certain number of features. 
    For example, all of the NJ ArcGIS servers have a request limit of 2000 features. 
    Recursively call the basic URL several times, while appending query restrictions to it.

    :param base_query_url: Starting string of the URL to call.
                     Should be formatted as though you are starting a query in the 'where' clause -
                     if only wanting to use the ObjectIDs, make sure it contains
                     'where=+1%3D1' at the end of the string. Other query parameters should be
                     predefined before this.
    :param lower_bound: minimum ObjectID of query value (no ObjectIDs of 0 exist).
                        Best to start at 0 for external calls.
                        Can be int or string, but should only contain the number.
    :param upper_bound: maximum ObjectID of query value
                        Can be int or string, but should only contain the number.
    :return None if bad connection or empty features, otherwise a dictionary with:
            - The url as the 'url' key
            - The raw data as the 'raw_data' key
            - The access time as the 'access_time' key
            - The last modified time as the 'updated' key
    '''
    url = base_query_url + '+AND+ObjectId+>+' + str(lower_bound) + '+AND+ObjectId+<+' + str(upper_bound)
    
    # prevent infinite loops in case of connection failure
    try:
        response = requests.get(url)
        response.raise_for_status()
    except requests.exceptions.RequestException:
        '''
        Just throw the generic exception.
        We probably can't do too much with a connection failure other than
        stop it from killing the script.
        '''
        print(f'Got a bad connection for {url}')
        return None

    access_time = datetime.datetime.utcnow()
    updated = determine_updated_timestep(response)
    raw_data = response.json()
    response = None
    # if the length is 0, no need to continue querying
    try:
        if len(raw_data[FEATURES]) == 0:
            return None
    except KeyError:
        # in case the features don't exist
        print(f'There were no features in the json at {url}')
        return None
    return {URL_DICT: url, ACCESS_TIME_DICT: access_time, 
            UPDATED_DICT: updated, RAW_DATA_DICT: raw_data}

def fill_in_df(df_list, dict_info, columns):
    if isinstance(df_list, list):
        all_df = []
        for each_df in df_list:
            all_df.append(fill_in_df_iter(each_df, dict_info, columns))
        return pd.concat(all_df)
    else:
        return fill_in_df_iter(df_list, dict_info, columns)

def fill_in_df_iter(each_df, dict_info, columns):
    for key in dict_info.keys():
        each_df[key] = dict_info[key]
    df_columns = list(each_df.columns)
    for column in columns:
        if column not in df_columns:
            each_df[column] = nan
        else:
            pass
    return each_df.reindex(columns=columns)

country = 'US'
state = 'New Jersey'
columns = Headers.updated_site
columns.extend([
    'unknown_deaths', 'percent_positive', 'lab_deaths',
    'new_cases', 'new_deaths',
    'facility', 'facility_type', 'facility_beds',
    'facility_count', 'facility_cases', 'facility_deaths',
    'patients_on_ventilator',
    'average_days_on_ventilator', 
    # ppe_ward_type = 'other', 'medical surgical', 'intensive care', 'critical care'
    'ppe_ward_type', 'beds_occupied', 'beds_available',
    'hospital_discharges_and_deaths_past_day', 'hospital_discharges_past_day', 'hospital_deaths_past_day',
    'residents', 'residents_tested', 'residents_positive', 'residents_negative', 
    'residents_pending', 'residents_deaths', 'residents_hospitalized', 'residents_recovered',
    'staff', 'staff_tested', 'staff_positive', 'staff_negative', 'staff_pending', 'staff_deaths',
    '211_calls', '211_text_enrollments', 'njpies_calls_of_day', 'njpies_calls_total'
])

row_csv = []

'''
Unlike most of the scripts, this script gradually appends data to the file
instead of all at once, to avoid possible memory issues.
'''
now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ', '_') + dt_string + '.csv'

## state data
# 211 data from this FeatureService is junk
resolution = 'state'
url = 'https://services7.arcgis.com/Z0rixLlManVefxqY/ArcGIS/rest/services/survey123_cb9a6e9a53ae45f6b9509a23ecdf7bcf/FeatureServer/0/query?where=1%3D1&orderBy=EditDate+desc&outFields=*&returnGeometry=false&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
response = None

for feature in raw_data[FEATURES]:
    attributes = feature[ATTRIBUTES]
    localized_updated = datetime.datetime.utcfromtimestamp(attributes['_date'] / 1000)
    cases = read_number(attributes['total_positives'])
    deaths = read_number(attributes['total_deaths'])
    presumptive = read_number(attributes['unknown_positives'])
    unknown_deaths = read_number(attributes['unknown_deaths'])
    negatives = read_number(attributes['total_negatives'])
    tested = read_number(attributes['total_tests_reported'])
    percent_positive = attributes['percent_positivity']
    lab_positives = attributes['major_lab_positives']
    lab_deaths = read_number(attributes['lab_confirmed_ltc_deaths'])
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
        cases, localized_updated, deaths, presumptive,
        nan, tested, nan, negatives,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, lab_positives, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan, # start custom values
        unknown_deaths, percent_positive, lab_deaths,
        nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan,
        nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan, nan,
        nan, nan, nan, nan])

raw_data = None
df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, mode='a', index=False)
df = None
row_csv = []

# state - 211 / NJ-PIES data
url = 'https://services7.arcgis.com/Z0rixLlManVefxqY/ArcGIS/rest/services/survey123_3c9c18a1d6f64a558b9aaeb285efab40_stakeholder/FeatureServer/0/query?where=1%3D1&orderBy=EditDate+desc&outFields=*&returnGeometry=false&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
response = None

for feature in raw_data[FEATURES]:
    attributes = feature[ATTRIBUTES]
    localized_updated = datetime.datetime.utcfromtimestamp(attributes['CreationDate'] / 1000)
    calls_211 = attributes['_211_calls']
    texts_211 = attributes['_211_text_enrollments']
    njpies_daily = attributes['njpies_calls']
    njpies_total = attributes['total_njpies_calls']
    '211_calls', '211_text_enrollments', 'njpies_calls_of_day', 'njpies_calls_total'
    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
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
        nan, nan, # start custom values
        nan, nan, nan,
        nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan,
        nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan, nan,
        calls_211, texts_211, njpies_daily, njpies_total])

raw_data = None
df = pd.DataFrame(row_csv)
df.to_csv(file_name, mode='a', index=False, header=False)
df = None
row_csv = []

# general state data

## county data
# contains county LTC data as well
url = 'https://services7.arcgis.com/Z0rixLlManVefxqY/ArcGIS/rest/services/DailyCaseCounts/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
response = None

resolution = 'county'
for feature in raw_data[FEATURES]:
    attributes = feature[ATTRIBUTES]
    county = attributes['COUNTY']
    region = attributes['Region']
    cases = read_number(attributes['TOTAL_CASES'])
    deaths = read_number(attributes['TOTAL_DEATHS'])
    new_cases = read_number(attributes['NEW_CASES'])
    new_deaths = read_number(attributes['NEW_DEATHS'])
    facility_count = read_number(attributes['Number_of_Facilities'])
    facility_cases = read_number(attributes['Number_COVID_Cases_Confirmed'])
    facility_deaths = read_number(attributes['Total_Number_of_COVID_Deaths_'])
    row_csv.append([
        'state', country, state, region,
        url, get_raw_data(raw_data), access_time, county,
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
        nan, nan, # start custom values
        nan, nan, nan,
        new_cases, new_deaths,
        nan, nan, nan,
        facility_count, facility_cases, facility_deaths,
        nan,
        nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan, nan,
        nan, nan, nan, nan])

raw_data = None
df = pd.DataFrame(row_csv)
df.to_csv(file_name, mode='a', index=False, header=False)
df = None
row_csv = []

### PPE CAPACITY ###
'''
74 results per latest timestep

Need to make several requests to get all data - max is 2000 features per request.

Get distinct values to check for with this query:

https://services7.arcgis.com/Z0rixLlManVefxqY/ArcGIS/rest/services/PPE_Capacity/FeatureServer/0/query?where=1%3D1&outFields=structure_measure_identifier&returnDistinctValues=true&orderByFields=structure_measure_identifier+desc&f=pjson

This could probably be simplified considerably using 'other' and 'other_value'
'''
base_url = 'https://services7.arcgis.com/Z0rixLlManVefxqY/ArcGIS/rest/services/PPE_Capacity/FeatureServer/0/query?outFields=*&f=json&orderByFields=survey_period+desc&where=structure_measure_identifier+%3D+'
resolution = 'facility'
facility_type = 'hospital'
# query strings from getting the distinct values for structure_measure_identifier
smi1 = "'Total+%23+of+COVID+Patients+Currently+on+a+Ventilator'"
smi2 = "'COVID-19+Positive+and+PUI+Patients+Combined+in+a+-+Other+Bed'"
smi3 = "'COVID-19+Positive+and+PUI+Patients+Combined+in+a+-+Medical+Surgical+Bed'"
smi4 = "'COVID-19+Positive+and+PUI+Patients+Combined+in+a+-+Intensive+Care+Bed'"
smi5 = "'COVID-19+Positive+and+PUI+Patients+Combined+in+a+-+Critical+Care+Bed'"
smi6 = "'Case+count+of+persons+under+investigation+%28PUI%29+%2F+presumptive+positive+cases+currently+in+the+hospital'"
smi7 = "'Case+count+of+COVID-19+positive+cases+currently+in+the+hospital'"
smi8 = "'Average+Number+of+Days+on+a+Ventilator+%28all+ventilators+combined%29'"
smi9 = "'Available+Beds+-+Other'"
smi10 = "'Available+Beds+-+Medical+Surgical'"
smi11 = "'Available+Beds+-+Intensive+Care'"
smi12 = "'Available+Beds+-+Critical+Care'"
smi13 = "'%23+of+COVID+Patients+Discharged+from+the+Hospital+%28past+24+hours%29'"
smi14 = "'%23+of+COVID+%2B+Patients+Discharged+from+Hospital+-+Excluding+Deaths+%28Past+24+hours%29'"
smi15 = "'%23+of+COVID+%2B+Patients+Discharged+from+Hospital+-+Deaths+Only+%28Past+24+hours%29'"
structure_measure_identifiers = (
    smi1, smi2, smi3, smi4, smi5,
    smi6, smi7, smi8, smi9, smi10,
    smi11, smi12, smi13, smi14, smi15
)

for smi in structure_measure_identifiers:
    base_query_url = base_url + smi
    lower_bound = 0
    upper_bound = 20000
    increment = 20000
    while True:
        results = get_arcgis_data(base_query_url, lower_bound, upper_bound)
        if results == None:
            print(f'NEW JERSEY: Query stopped at lower: {lower_bound} , upper: {upper_bound} for smi: {smi}')
            break
        url = results[URL_DICT]
        access_time = results[ACCESS_TIME_DICT]
        updated = results[UPDATED_DICT]
        raw_data = results[RAW_DATA_DICT]

        # hackish code, but trying to avoid using other_value here
        if (smi == smi1): # Total # of COVID Patients Currently on a Ventilator
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                patients_on_ventilator = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    patients_on_ventilator,
                    nan,
                    nan, nan, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi2): # COVID-19 Positive and PUI Patients Combined in a - Other Bed
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'other'
                beds_occupied = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, beds_occupied, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi3): # COVID-19 Positive and PUI Patients Combined in a - Medical Surgical Bed
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'medical surgical'
                beds_occupied = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, beds_occupied, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi4): # COVID-19 Positive and PUI Patients Combined in a - Intensive Care Bed
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'intensive care'
                beds_occupied = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, beds_occupied, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi5): # COVID-19 Positive and PUI Patients Combined in a - Critical Care Bed
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'critical care'
                beds_occupied = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, beds_occupied, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi6): # Case count of persons under investigation (PUI) / presumptive positive cases currently in the hospital
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                presumptive = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
                    nan, localized_updated, nan, presumptive,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    nan, nan, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi7): # Case count of COVID-19 positive cases currently in the hospital
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                cases = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
                    cases, localized_updated, nan, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    nan, nan, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi8): # Average Number of Days on a Ventilator (all ventilators combined)
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                average_days_on_ventilator = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    average_days_on_ventilator,
                    nan, nan, nan,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi9): # Available Beds - Other
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'other'
                beds_available = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, nan, beds_available,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi10): # Available Beds - Medical Surgical
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'medical surgical'
                beds_available = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, nan, beds_available,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])  
        elif (smi == smi11): # Available Beds - Intensive Care
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'intensive care'
                beds_available = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, nan, beds_available,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi12): # Available Beds - Critical Care
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                ppe_ward_type = 'critical care'
                beds_available = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    ppe_ward_type, nan, beds_available,
                    nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi13): # of COVID Patients Discharged from the Hospital (past 24 hours)
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                hospital_discharges_and_deaths_past_day = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    nan, nan, nan,
                    hospital_discharges_and_deaths_past_day, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi14): # # of COVID + Patients Discharged from Hospital - Excluding Deaths (Past 24 hours)
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                hospital_discharges_past_day = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    nan, nan, nan,
                    nan, hospital_discharges_past_day, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])
        elif (smi == smi15): # # of COVID + Patients Discharged from Hospital - Deaths Only (Past 24 hours)
            for feature in raw_data[FEATURES]:
                attributes = feature[ATTRIBUTES]
                localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_period'] / 1000)
                facility = attributes['FacilityName']
                county = attributes['County']
                region = attributes['GeographicRegion']
                hospital_deaths_past_day = read_number(attributes['Value'])
                row_csv.append([
                    'state', country, state, nan,
                    url, get_raw_data(raw_data), access_time, nan,
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
                    nan, nan, # start custom values
                    nan, nan, nan,
                    nan, nan,
                    facility, facility_type, nan,
                    nan, nan, nan,
                    nan,
                    nan,
                    nan, nan, nan,
                    nan, nan, hospital_deaths_past_day,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan,
                    nan, nan, nan, nan, nan, nan,
                    nan, nan, nan, nan])

        lower_bound += increment
        upper_bound += increment

    # one indentation - append to the file until making a new SMI query
    raw_data = None
    df = pd.DataFrame(row_csv)
    df.to_csv(file_name, mode='a', index=False, header=False)
    df = None
    row_csv = []

## psychiatric hospitals
resolution = 'facility'
facility_type = 'psychiatric'
'''
To get only the most recent data, add
&resultRecordsCount=4
to the URL (already ordered by date desc)
'''
url = 'https://services7.arcgis.com/Z0rixLlManVefxqY/ArcGIS/rest/services/NJ_State_Psychiatric_Hospital_Survey/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&orderByFields=survey_datetime+desc&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
response = None

for feature in raw_data[FEATURES]:
    attributes = feature[ATTRIBUTES]
    localized_updated = datetime.datetime.utcfromtimestamp(attributes['survey_datetime'] / 1000)
    zipcode = attributes['ZIP']
    facility = attributes['FACILITY']
    residents = attributes['current_patient_census']
    residents_tested = attributes['total_number_of_patients_tested']
    residents_positive = attributes['number_of_positive_patients']
    residents_negative = attributes['number_of_negative_patients']
    residents_pending = attributes['number_of_pending_patient_tests']
    residents_deaths = attributes['patient_deaths']
    staff = attributes['current_number_of_staff']
    staff_tested = attributes['total_staff_tested']
    staff_positive = attributes['number_of_positive_staff']
    staff_negative = attributes['number_of_negative_staff']
    staff_pending = attributes['number_of_pending_staff_tests']
    staff_deaths = attributes['staff_deaths']
    row_csv.append([
        'state', country, state, zipcode,
        url, get_raw_data(raw_data), access_time, nan,
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
        nan, nan, # start custom values
        nan, nan, nan,
        nan, nan,
        facility, facility_type, nan,
        nan, nan, nan,
        nan,
        nan,
        nan, nan, nan,
        nan, nan, nan,
        residents, residents_tested, residents_positive, residents_negative,
        residents_pending, residents_deaths, nan, nan,
        staff, staff_tested, staff_positive, staff_negative, staff_pending, staff_deaths,
        nan, nan, nan, nan])

raw_data = None
df = pd.DataFrame(row_csv)
df.to_csv(file_name, mode='a', index=False, header=False)
df = None
row_csv = []

## veteran's homes
resolution = 'facility'
facility_type = 'veterans memorial home'
'''
To get only the most recent dates, add
&resultRecordCount=3
to the URL (already ordered by date desc)
'''
url = 'https://services7.arcgis.com/Z0rixLlManVefxqY/ArcGIS/rest/services/DMAVA_Veteran_Homes/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&orderByFields=_date+desc&f=json'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
response = None

for feature in raw_data[FEATURES]:
    attributes = feature[ATTRIBUTES]
    localized_updated = datetime.datetime.utcfromtimestamp(attributes['_date'] / 1000)
    beds = attributes['total_licensed_beds']
    residents = attributes['todays_census']
    residents_positive = attributes['covid_19_confirmed_residents']
    residents_pending = attributes['covid_19_residents_pending_resu']
    resident_deaths = attributes['total_resident_covid_19_deaths']
    residents_hospitalized = attributes['total_residents_hospitalized']
    residents_recovered = attributes['residents_recovered_from_covid_']
    staff = attributes['total_number_of_facility_staff']
    staff_positive = attributes['total_confirmed_covid_19_staff']
    staff_pending = attributes['total_covid_19_pending_results']
    staff_deaths = attributes['total_staff_deaths_suspectedcon']

    row_csv.append([
        'state', country, state, nan,
        url, get_raw_data(raw_data), access_time, nan,
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
        nan, nan, # start custom values
        nan, nan, nan,
        nan, nan,
        facility, facility_type, beds,
        nan, nan, nan,
        nan,
        nan,
        nan, nan, nan,
        nan, nan, nan,
        residents, nan, residents_positive, nan,
        residents_pending, residents_deaths, residents_hospitalized, residents_recovered,
        staff, nan, staff_positive, nan, staff_pending, staff_deaths,
        nan, nan, nan, nan])

raw_data = None
df = pd.DataFrame(row_csv)
df.to_csv(file_name, mode='a', index=False, header=False)
df = None
row_csv = []

## LTC data

url = 'https://www.state.nj.us/health/healthfacilities/documents/LTC_Facilities_Outbreaks_List.xlsx'
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)

# LTC by facility
resolution = 'facility'
ltc_df = pd.read_excel(BytesIO(response.content), sheet_name=0)
response = None
raw_df = get_raw_dataframe(ltc_df)
ltc_df.columns = ['county', 'facility', 'region', 'facility_cases', 'facility_deaths']
# drop first row (actual column headers) and empty rows
ltc_df = ltc_df.iloc[2:]
ltc_df = ltc_df.dropna(subset=['facility'])
ltc_df = ltc_df.fillna(0)

dict_info = {'provider': 'state', 'country': country, "url": url,
                   "state": state, "resolution": resolution,
                   "page": raw_df, "access_time": access_time,
                   "updated": updated}
ltc_df = fill_in_df(ltc_df, dict_info, columns)

'''
only need the first excel sheet
second sheet has county data, generally behind the feature server already being queried
third sheet has no useful information
'''

ltc_df.to_csv(file_name, mode='a', index=False, header=False)
