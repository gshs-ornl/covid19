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

country = 'US'
url = 'https://services.arcgis.com/iFBq2AW9XO0jYYF7/arcgis/rest/services/NCCovid19/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'North Carolina'
resolution = 'county'
columns = Headers.updated_site
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
        url, str(raw_data), access_time, county,
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
        nan, nan])


with open('north_carolina_data.json', 'w') as f:
    json.dump(raw_data, f)


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


resolution = 'county'
url = "https://www.ncdhhs.gov/divisions/public-health/covid19/covid-19" \
      "-nc-case-count#by-counties"
response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
html_text = response.text
soup = BeautifulSoup(html_text, 'html.parser')

dict_info_state = {'provider': 'state', 'country': country, "url": url,
                   "state": state, "resolution": "state",
                   "page": str(html_text), "access_time": access_time,
                   "updated": updated}

table = soup.find_all('table')[0]
rows = table.find_all('tr')
data = []
# source: https://stackoverflow.com/questions/23377533/python-beautifulsoup-parsing-table
for row in rows:
    cols = row.find_all('td')
    cols = [ele.text.strip() for ele in cols]
    data.append([ele for ele in cols if ele]) # Get rid of empty values
state_df = pd.DataFrame(data, columns=['cases', 'deaths', 'tested', 'hospitalized', 'other_value'])
state_df = state_df.dropna()
state_df['other'] = 'Number of Counties'

state_df = fill_in_df(state_df, dict_info_state, columns)

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ','_') + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
all_df = pd.concat([df, state_df])
all_df.to_csv(file_name, index=False)
