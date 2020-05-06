#!/usr/bin/env python3

import requests
import datetime
import json
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

columns = Headers.updated_site
country = 'US'
state = 'Puerto Rico'
municipal_url = 'https://services5.arcgis.com/klquQoHA0q9zjblu/arcgis/rest/services/Municipios_Joined/FeatureServer/0/query?f=json&where=Total%3C%3E0&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Total%20desc&resultOffset=0&resultRecordCount=78&resultType=standard&cacheHint=true'
region_url = 'https://services5.arcgis.com/klquQoHA0q9zjblu/arcgis/rest/services/Regiones_Joined/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=Total%20desc&resultOffset=0&resultRecordCount=4000&resultType=standard&cacheHint=true'
total_url =  'https://services5.arcgis.com/klquQoHA0q9zjblu/arcgis/rest/services/Datos_Totales/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&resultOffset=0&resultRecordCount=50&resultType=standard&cacheHint=true'
row_csv = []
alias = {'T_Camas_Adult_Disp': 'Total Adult Beds Available',
         'T_Camas_Adult_Int_Disp': 'Total Adult Intensive Beds Available',
         'T_Camas_Adult_Int_Occ': 'Total Intensive Adult Beds Occupied',
         'T_Camas_Ped_Int_Disp': 'Total Pediatric Intensive Beds Available',
         'T_Camas_Ped_Int_Occ': 'Total Pediatric Intensive Beds Occupied',
         'T_Cuartos_PSINeg_Disp': 'Total of Negative Pressure Rooms Available',
         'T_Cuartos_PSINeg_Occ': 'Total of Negative Pressure Rooms Available',
         'T_Vent_Adult_Disp': 'Total Adult Ventilator Available',
         'T_Vent_Adult_Occ': 'Total Adult Ventilator Occupied',
         'T_Vent_Ped_Disp': 'Total Pediatric Ventilators Available',
         'T_Vent_Ped_Occ': 'Total of Occupied Pediatric Ventilators',
         'T_Morgue_Disp': 'Total Morgue Spaces Available',
         'T_Morgue_Occ': 'Total Morgue Spaces Occupied',
         'T_Paciente_Adult': 'Total Census of Adult Patients',
         'T_Paciente_Ped': 'Total Census of Pediatric Patients',
         'T_Casos_Nuev_Ult_Inf': 'Total new cases since the last report',
         'T_Casos_Nuev_DS': 'Total New Cases (Department of Health)',
         'T_Casos_Nuev_AV': 'Total New Cases (Veterans Administration)',
         'T_Casos_Nuev_LabPriv': 'Total New Cases (Private Laboratories)',
         'T_Casos_Inconcluso': 'Total Unfinished Cases',
         'T_Vent_Rec': 'Total Ventilators Received',
         'T_Vent_Entr': 'Total Ventilators Delivered',
         'T_Camas_Ped_Disp': 'Total Pediatric Beds Available',
         'T_Cuartos_PSiNeg': 'Total Rooms Negative Pressure',
         'T_Camas_Int_Adult': 'Total Intensive Adult Beds',
         'T_Camas_Int_Ped': 'Total Pediatric Intensive Beds',
         'T_Vent_Adult': 'Total Adult Ventilators',
         'T_Vent_Ped': 'Total Pediatric Ventilators',
         'T_Camas_Adult_Available': 'Total Adult Beds Available',
         'T_Camas_Ped_Available': 'Total Pediatric Beds Available',
         'T_Camas_Adulto': 'Total Adult Beds',
         'T_Camas_Ped': 'Total Pediatric Beds',
         'T_Pacientes_Int_Covid': 'Total of Intensive Patients by COVID-19',
         'T_Paciente_Adult_Int_Covid': 'Total Adult Patients Hospitalized for COVID in Intensive Care Beds',
         'T_Paciente_Ped_Int_Covid': 'Total Pediatric Patients Hospitalized by COVID in Intensive Care Beds',
         'T_Vent_Covid': 'Total of Patients in Ventilator by COVID-19',
         'T_Vent_Adult_Covid': 'Total Adult Patients on Ventilator by COVID-19',
         'T_Vent_Ped_Covid': 'Total Pediatric Ventilator Patients by COVID-19',
         'T_Hospitalizado_Ped': 'Total Pediatric Patients Hospitalized by Covid'
         }


# municipal_url
resolution = 'municipal'
url = municipal_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
for feature in raw_data['features']:
    attribute = feature['attributes']
    region = attribute['municipio']
    cases = attribute['Total']
    row_csv.append([
            'state', country, state, region,
            url, str(raw_data), access_time, nan,
            cases, updated, nan, nan,
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

# region_url
resolution = 'region'
url = region_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
for feature in raw_data['features']:
    attribute = feature['attributes']
    region = attribute['RegionSalud']
    cases = attribute['Total']
    row_csv.append([
            'state', country, state, region,
            url, str(raw_data), access_time, nan,
            cases, updated, nan, nan,
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


# total_url
resolution = 'state'
url = total_url
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

attribute = raw_data['features'][0]['attributes']
deaths = attribute['T_Muertes_Combinadas'] #['T_Fatalidades']
cases = attribute['T_Casos_Unicos']#['T_Casos_Pos']
negative = attribute['T_Casos_Neg']
pending = attribute['T_Casos_Pend']
hospitalized = attribute['T_Hospitalizados']
recovered = attribute['T_Recuperados']

gender_list = ['T_Fem', 'T_Masc']
age_group_list = ['T_Menor_10', 'T_10_19', 'T_20_29', 'T_30_39', 'T_40_49',
                  'T_50_59', 'T_60_69', 'T_70_79', 'T_Mayor_80',
                  'Edad_No_Dis']


for age_group in age_group_list:
    age_range = age_group
    age_cases = attribute[age_range]
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, updated, deaths, nan,
        recovered, nan, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, nan, pending,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age_range, age_cases, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])

for gender in gender_list:
    sex = gender
    sex_counts = attribute[sex]
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, updated, deaths, nan,
        recovered, nan, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, nan, pending,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, sex, sex_counts, nan,
        nan, nan])

for key in alias.keys():
    other = alias[key]
    other_value = attribute[key]
    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
        cases, updated, deaths, nan,
        recovered, nan, hospitalized, negative,
        nan, nan, nan, nan, nan,
        nan, nan, pending,
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
if path and not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ', '_') + dt_string + '.csv'

dfs = pd.DataFrame(row_csv, columns=columns)
dfs.to_csv(file_name, index=False)