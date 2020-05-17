#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep

country = 'US'
# ESRI
county_cases_url = 'https://services1.arcgis.com/RQG3sksSXcoDoIfj/arcgis/rest/services/MN_COVID19_County_Tracking_Public_View/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state_url = 'https://services2.arcgis.com/V12PKGiMAH7dktkU/arcgis/rest/services/MyMapService/FeatureServer/0/query?f=json&where=1%3D1&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&resultOffset=0&resultRecordCount=50&resultType=standard&cacheHint=true'
# web table
state_table_url = 'https://www.health.state.mn.us/diseases/coronavirus/situation.html'
state = 'Minnesota'
columns = Headers.updated_site
row_csv = []

# County-level data: cases
url = county_cases_url
resolution = 'county'

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['CTY_NAME']
    cases = attribute['COVID19POS']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
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

# State-level
url = state_url
resolution = 'state'
response = requests.get(url, timeout=None)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()
other_keys = {'TotalCases': 'Released from isolation',
              'EvrHospNo': 'Non-hospitalized',
              'EvrHospMis': 'Missing hospital cases'}
genders = ['Male', 'Female']
cases_keys = ['RaceAsian', 'RacePacifi', 'RaceWht', 'RaceBlk',
              'RaceAsnPac', 'RaceAmerIn', 'RaceOther',
              'RaceUnk', 'EthnHisp', 'EthnNonHis', 'EthnUnk']
deaths_keys = ['DeathWht', 'DeathBlk', 'DeathAsian', 'DeathPacif',
               'DeathNativ', 'DeathOther', 'DeathUnkno',
               'DeathHisp', 'DeathNonHi', 'DeathHispU']
exposure_types = {'ExpsrCrzSh': 'Travel',
                  'ExpsrIntrn': 'Congregate Living',
                  'ExpsrLklyE': 'Health Care',
                  'ExpsrAnthr': "Community Spread",
                  'ExpsrInMN': "Community Unknown",
                  'ExpsrMsng': "Unknown"}
resident_types = {'ResPriv': 'Private', 'ResLTCF': 'LCTF/Assisted Living',
                  'ResHmlShel': 'Homeless', 'ResJail': "Jail",
                  'ResCollDrm': 'Residential Behavioural Health',
                  'ResOther': 'Other', 'ResMsng': 'Missing'}

attribute = raw_data['features'][0]['attributes']
state_cases = attribute['TotalCases']
hospitalized = attribute['EvrHospYes']
icu = attribute['EvrICUYes']
state_deaths = attribute['OutcmDied']
row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
            state_cases, updated, state_deaths, nan,
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
for other_list in [other_keys, exposure_types, resident_types]:
    for other_key in other_list.keys():
        other = other_list.get(other_key)
        other_value = attribute[other_key]

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, nan,
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
            other, other_value])

for gender in genders:
    sex = gender
    sex_counts = attribute[gender]

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
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
        other, other_value])


# State-level data
def fill_in_df(df_list, dict_info, columns):
    if isinstance(df_list, list):
        all_df = []
        count = 1
        for each_df in df_list:
            if isinstance(each_df, pd.DataFrame):
                each_df['provider'] = dict_info['provider']
                each_df['country'] = dict_info['country']
                each_df['state'] = dict_info['state']
                each_df['resolution'] = dict_info['resolution']
                each_df['url'] = dict_info['url']
                each_df['page'] = str(dict_info['page'])
                each_df['access_time'] = dict_info['access_time']
                df_columns = list(each_df.columns)
                for column in columns:
                    if column not in df_columns:
                        each_df[column] = nan
                    else:
                        pass
                all_df.append(each_df.reindex(columns=columns))
            else:
                print(df_list[count], "Not dataframe ", type(each_df))
            count = count + 1
        final_df = pd.concat(all_df)
    else:
        df_list['provider'] = dict_info['provider']
        df_list['country'] = dict_info['country']
        df_list['state'] = dict_info['state']
        df_list['resolution'] = dict_info['resolution']
        df_list['url'] = dict_info['url']
        df_list['page'] = str(dict_info['page'])
        df_list['access_time'] = dict_info['access_time']
        df_columns = list(df_list.columns)
        for column in columns:
            if column not in df_columns:
                df_list[column] = nan
            else:
                pass
        final_df = df_list.reindex(columns=columns)
    return final_df


df = pd.read_html(state_table_url, match='.*')
access_time = datetime.datetime.utcnow()
dict_info_county = {'provider': 'state', 'country': country,
                    "url": state_table_url,
                    "state": state, "resolution": "county",
                    "page": str(df), "access_time": access_time}

dict_info_state = {'provider': 'state', 'country': country,
                    "url": state_table_url,
                    "state": state, "resolution": "state",
                    "page": str(df), "access_time": access_time}

daily_update_df = df[0]
newly_cases_df = df[1]
tested_raw = df[4]
deaths_df = df[6]
hospitalization = df[7]
age_group_cases_deaths = df[8]
gender_cases = df[9]
race_cases_deaths = df[10][0:8]
eth_cases_deaths = df[10][9:]
exposure_cases = df[11]
county_cases_deaths = df[12]
res_cases = df[13]

# Daily update
cases = int(float(daily_update_df.iloc[0][0].replace(
    ' \tTotal positive (cumulative)', '').replace(',', '')))
other_keys = ['Newly reported cases', 'Newly reported deaths']
other_values = [int(float(daily_update_df[0].iloc[1][0].replace('\t'+other_keys[0], '').replace(',', ''))),
                int(float(daily_update_df[0].iloc[1][1].replace('\t'+other_keys[1], '').replace(',', '')))]

state_cases_df = pd.DataFrame({'cases': [cases]})
daily_cases_deaths_df = pd.DataFrame(
    {'other': other_keys, 'other_value': other_values})

# Newly reported cases by
newly_cases_txt = 'Number of newly reported cases'
newly_cases_df = newly_cases_df.rename(
    columns={'County': 'county', newly_cases_txt: 'other_value'})
newly_cases_df['other'] = newly_cases_txt


# County-level: newly reported deaths by county of residence
newly_reported_deaths_counties_text = 'Number of newly reported deaths'
newly_reported_deaths_counties = df[2].rename(
    columns={'County of residence': 'county', 'Age group': 'age_range',
             newly_reported_deaths_counties_text: 'other_value'})
newly_reported_deaths_counties['other'] = newly_reported_deaths_counties_text

# State-level: newly reported deaths by residence type
newly_reported_deaths_res = df[3].rename(
    columns={'Residence type': 'other',
             'Number of newly reported deaths': 'other_value'})
newly_reported_deaths_res['other'] = 'residence_type_' + newly_reported_deaths_res['other']

new_date = []
# Get the latest date
tested_raw = tested_raw.rename(columns={
    'Date reported to MDH': 'updated',
    'Total approximate number of completed tests': 'tested'})
date_list = tested_raw['updated'].to_list()
for date in date_list:
    new_date.append(datetime.datetime.strptime(date, '%m/%d'))
latest_date = sorted(new_date)[-1].strftime('%-m/%-d')

# State-level: all testing data
tested_raw = tested_raw[tested_raw['updated'] == latest_date]

# State-level: tested
tested_state = tested_raw[['tested']]

# State-level: other testing info
state_lab_df_txt = 'Completed tests reported from the MDH Public Health Lab (daily)'
state_lab_df = tested_raw[['updated', state_lab_df_txt]]
state_lab_df.columns = ['updated', 'other_value']
state_lab_df['other'] = state_lab_df_txt

ext_lab_df_txt = 'Completed tests reported from external laboratories (daily)'
ext_lab_df = tested_raw[['updated', ext_lab_df_txt]]
ext_lab_df.columns = ['updated', 'other_value']
ext_lab_df['other'] = ext_lab_df_txt

# State-level: deaths
deaths_df = deaths_df.rename(
    columns={'Date reported': 'updated',
             'Newly reported deaths (daily)': 'other_value',
             'Total deaths': 'deaths'})
deaths_df = deaths_df[deaths_df['updated'] == latest_date]
deaths_df['other'] = 'Newly reported deaths (daily)'
state_deaths = deaths_df[['deaths']]
state_daily_deaths = deaths_df[['updated', 'other', 'other_value']]

# State-level: hospitalization
hospitalization = hospitalization.rename(
    columns={'Date reported': 'updated',
             'Total hospitalizations': 'hospitalized',
             'Total ICU hospitalizations': 'icu'})
hospitalization = hospitalization[hospitalization['updated'] == latest_date]
hospitalized = hospitalization[['hospitalized', 'icu']]

# Other: ICU daily
icu_daily = hospitalization[['updated', 'Hospitalized in ICU (daily)']]
icu_daily.columns = ['updated', 'other_value']
icu_daily['other'] = 'Hospitalized in ICU (daily)'

# Other: not in ICU daily
not_icu_daily = hospitalization[['updated', 'Hospitalized, not in ICU (daily)']]
not_icu_daily.columns = ['updated', 'other_value']
not_icu_daily['other'] = 'Hospitalized, not in ICU (daily)'

# State-level: cases and deaths by age group
age_group_cases_deaths = age_group_cases_deaths.rename(
    columns={'Age Group': 'age_range', 'Number of Cases': 'cases',
             'Number of Deaths': 'deaths'})

# State-level: cases by gender
gender_cases = gender_cases.rename(
    columns={'Gender': 'sex', 'Number of Cases': 'sex_counts'})

# State-level: cases and deaths by race
race_cases_deaths = race_cases_deaths.rename(
    columns={'Race': 'other_value', 'Number of Cases': 'cases',
             'Number of Deaths': 'deaths'})
race_cases_deaths['other'] = 'race'

# State-level: cases and deaths by ethnicity
eth_cases_deaths = eth_cases_deaths.rename(
    columns={'Race': 'other_value', 'Number of Cases': 'cases',
             'Number of Deaths': 'deaths'})
eth_cases_deaths['other'] = 'ethnicity'

# State-level: Exposure - cases
exposure_cases = exposure_cases.rename(
    columns={'Likely Exposure': 'other_value', 'Number of Cases': 'cases'})
exposure_cases['other'] = 'Likely Exposure'

# County-level: cases and deaths
county_cases_deaths = county_cases_deaths.rename(
    columns={'County': 'county', 'Cases': 'cases', 'Deaths': 'deaths'})

# State-level: cases by residence type
res_cases = res_cases.rename(
    columns={'Residence Type': 'other_value',
             'Number of Cases': 'cases'})
res_cases['other'] = 'Residence Type'

state_df = [state_cases_df, daily_cases_deaths_df, newly_reported_deaths_res,
            tested_state, state_lab_df, ext_lab_df,
            state_deaths, state_daily_deaths,
            hospitalized, icu_daily, not_icu_daily,
            age_group_cases_deaths, gender_cases,
            race_cases_deaths, eth_cases_deaths, exposure_cases, res_cases]
county_df = [newly_cases_df, newly_reported_deaths_counties,
             county_cases_deaths]

county_df = fill_in_df(county_df, dict_info_county, columns)
state_df = fill_in_df(state_df, dict_info_state, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state + dt_string + '.csv'

df = pd.concat([pd.DataFrame(row_csv, columns=columns),
                county_df, state_df])

df.to_csv(file_name, index=False)
