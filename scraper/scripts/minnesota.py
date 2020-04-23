#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
county_cases_url = 'https://services1.arcgis.com/RQG3sksSXcoDoIfj/arcgis/rest/services/MN_COVID19_County_Tracking_Public_View/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state_url = 'https://services2.arcgis.com/V12PKGiMAH7dktkU/arcgis/rest/services/MyMapService/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&resultOffset=0&resultRecordCount=50&resultType=standard&cacheHint=true'
state = 'Minnesota'
columns = Headers.updated_site
row_csv = []

# County-level data: cases
url = county_cases_url
resolution = 'county'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['CTY_NAME']
    cases = attribute['COVID19POS']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, nan, nan, nan,
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

# State-level
url = state_url
resolution = 'state'
raw_data = requests.get(url, timeout = None).json()
access_time = datetime.datetime.utcnow()
other_keys = {'TotalCases': 'Released from isolation',
              'EvrHospNo': 'Non-hospitalized',
              'EvrHospMisng': 'Missing hospital cases'}
genders = ['Male', 'Female']
cases_keys = ['RaceAsian', 'RacePacific', 'RaceWht', 'RaceBlk',
              'RaceAsnPacIsld', 'RaceAmerIndAlaNativ', 'RaceOther',
              'RaceUnk', 'EthnHisp', 'EthnNonHisp', 'EthnUnk']
deaths_keys = ['DeathWht', 'DeathBlk', 'DeathAsian', 'DeathPacific',
               'DeathNative', 'DeathOther', 'DeathUnknown',
               'DeathHisp', 'DeathNonHisp', 'DeathHispUnknown']
exposure_types = {'ExpsrCrzShp': 'Travel',
                  'ExpsrIntrntnl': 'Congregate Living',
                  'ExpsrLklyExpsr': 'Health Care',
                  'ExpsrAnthrState': "Community Unknown",
                  'ExpsrInMN': "Community Spread", 'ExpsrMsng': "Unknown"}
resident_types = {'ResPriv': 'Private', 'ResLTCF': 'LCTF/Assisted Living',
                  'ResHmlShelt': 'Homeless', 'ResJail': "Jail",
                  'ResCollDrm':'Residential Behavioural Health',
                  'ResOther': 'Other', 'ResMsng': 'Missing'}

attribute = raw_data['features'][0]['attributes']
state_cases = attribute['TotalCases']
hospitalized = attribute['EvrHospYes']
icu = attribute['EvrICUYes']
state_deaths = attribute['OutcmDied']
row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            state_cases, nan, state_deaths, nan,
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
for other_list in [other_keys, exposure_types,resident_types]:
    for other_key in other_list.keys():
        other = other_list.get(other_key)
        other_value = attribute[other_key]

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            nan, nan, nan, nan,
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

for gender in genders:
    sex = gender
    sex_counts = attribute[gender]

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        nan, nan, nan, nan,
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
        nan, nan])

# Cases and deaths by race and ethnicity
for cases_key in cases_keys:
    # cases = attribute[cases_key]
    other = 'cases_' + cases_key
    other_value = attribute[cases_key]

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        nan, nan, nan, nan,
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

for deaths_key in deaths_keys:
    if 'Hisp' in deaths_keys:
        indicator = 'Eth'
    else:
        indicator = 'Race'
    other = indicator + deaths_key
    other_value = attribute[deaths_key]

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        nan, nan, nan, nan,
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


now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
