#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
url = 'https://services2.arcgis.com/xtuWQvb2YQnp0z3F/ArcGIS/rest/services/Aggregate_County_Level_Data/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=ObjectId%20ASC&outSR=102100&resultOffset=0&resultRecordCount=50&cacheHint=true'
hospital_url = 'https://services2.arcgis.com/xtuWQvb2YQnp0z3F/arcgis/rest/services/Adam_Public_HOS/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'Pennsylvania'
columns = Headers.updated_site


response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

with open(state+'_county_data.json', 'w') as f:
    json.dump(raw_data, f)

resolution = 'county'

row_csv = []
alias = {}
other_keys = ['SUM_Available_Beds_Adult_Intens',
             'SUM_Available_Beds_Medical_and_',
             'SUM_Available_Beds_Pediatric_In',
             'SUM_Other_Beds_Airborne_Infecti',
             'SUM_COVID_19_Patient_Counts_Tot',
             'SUM_COVID_19_Patient_Counts_T_1',
             'SUM_COVID_19_Patient_Counts_T_2',
             'SUM_Ventilator_Counts_Ventilato',
             'SUM_Ventilator_Counts_Ventila_1'
             ]


for field in raw_data['fields']:
    name = field['name']
    if name in other_keys:
        alias[name] = field['alias']

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County']
    cases = attribute['Positive']
    deaths = attribute['Deaths']

    for other_key in other_keys:
        other = alias[other_key]
        other_value = attribute[other_key]
        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
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
            other, other_value])


response = requests.get(hospital_url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

with open(state+'_hospital_data.json', 'w') as f:
    json.dump(raw_data, f)

resolution = 'state'
hospital_alias = {}
other_keys = ['HospitalName']
hospital_alias_needed = ['Available_Beds_Adult_Intensive_',
              'Available_Beds_Adult_Intensive1',
              'Available_Beds_Adult_Intensiv_1',
              'Available_Beds_Adult_Intensiv_2',
              'Available_Beds_Medical_and_Surg',
              'Available_Beds_Medical_and_Su_1',
              'Available_Beds_Medical_and_Su_2',
              'Available_Beds_Medical_and_Su_3',
              'Available_Beds_Pediatric_Intens',
              'Available_Beds_Pediatric_Inte_1',
              'Available_Beds_Pediatric_Inte_2',
              'Available_Beds_Pediatric_Inte_3',
              'Available_Beds_Pediatric_Staffe',
              'Available_Beds_Pediatric_Curren',
              'Available_Beds_Pediatric_24hr_B',
              'Available_Beds_Pediatric_72hr_B',
              'Other_Beds_Airborne_Infection_I',
              'Other_Beds_Airborne_Infection_1',
              'Other_Beds_Airborne_Infection_2',
              'Other_Beds_Airborne_Infection_3',
              'COVID_19_Patient_Counts_Total_n',
              'COVID_19_Patient_Counts_Total_1',
              'COVID_19_Patient_Counts_Total_2',
              'COVID_19_Patient_Counts_Total_3',
              'COVID_19_Patient_Counts_How_man',
              'COVID_19_Patient_Counts_How_m_1',
              'COVID_19_Patient_Counts_How_m_2',
              'Ventilator_Counts_Ventilators_N',
              'Ventilator_Counts_Ventilators_1',
              'Ventilator_Counts_Ventilators_2',
              'Ventilator_Counts_Ventilators_3']

other_keys.extend(hospital_alias_needed)

for field in raw_data['fields']:
    name = field['name']
    if name in hospital_alias_needed:
        hospital_alias[name] = field['alias']


for feature in raw_data['features']:
    attribute = feature['attributes']
    lat = attribute['HospitalLatitude']
    lon = attribute['HospitalLongitude']

    for other_key in other_keys:
        if alias.get(other_key, None) is not None:
            other = alias[other_key]
        else:
            other = other_key
        other_value = attribute[other_key]

        row_csv.append([
            'state', country, state, nan,
            hospital_url, str(raw_data), access_time, nan,
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
            other, other_value])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
# "Last_Updated" field is not reported all the time so there is a need to fill
# missing data
df[['updated']] = df[['updated']].fillna(method='ffill')
df.to_csv(file_name, index=False)
