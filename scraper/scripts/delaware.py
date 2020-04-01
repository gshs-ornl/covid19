#!/usr/bin/env python3

import requests
import datetime
from numpy import nan
import pandas as pd
from cvpy.static import Headers


country = 'US'
url = 'https://services1.arcgis.com/PlCPCPzGOwulHUHo/ArcGIS/rest/services/DEMA_COVID_County_Boundary_Time_VIEW/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryPoint&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson&token='
state = 'Delaware'
columns = Headers.updated_site


raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

row_csv = []
state_keys = ['Range1', 'Range2', 'Range3', 'Range4', 'Range5']
alias = {}

for field in raw_data['fields']:
    name = field['name']
    if 'Range' in name:
        alias[name] = field['alias']

print(alias)

for feature in raw_data['features']:
    attribute = feature['attributes']
    if attribute["TYPE"] == 'mainland' and attribute['NAME'] != 'Statewide':
        resolution = 'county'
        county = attribute['NAME']
        cases = attribute['Presumptive_Positive']
        recovered = attribute['Recovered']
        deaths = attribute['Total_Death']
        hospitalized = attribute['Hospitalizations']
        negative_tests = attribute['NegativeCOVID']
        update_date = attribute['Last_Updated']
        if update_date is None:
            updated = nan
        else:
            update_date = float(attribute['Last_Updated'])
            updated = str(datetime.datetime.fromtimestamp(update_date/1000.0))

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, updated, deaths, nan,
            recovered, nan, hospitalized, negative_tests,
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

    elif attribute['NAME'] == 'Statewide':
        resolution = 'state'
        county = nan
        cases = attribute['Presumptive_Positive']
        recovered = attribute['Recovered']
        deaths = attribute['Total_Death']
        hospitalized = attribute['Hospitalizations']
        negative_tests = attribute['NegativeCOVID']
        cases_male = attribute['Male']
        cases_female = attribute['Female']
        update_date = attribute['Last_Updated']
        if update_date is None:
            updated = nan
        else:
            update_date = float(attribute['Last_Updated'])
            updated = str(datetime.datetime.fromtimestamp(update_date / 1000.0))
        for key in state_keys:

            age_range = alias[key]
            age_cases = attribute[key]

            row_csv.append([
                'state', country, state, nan,
                url, str(raw_data), access_time, county,
                cases, updated, deaths, nan,
                recovered, nan, hospitalized, negative_tests,
                nan, nan, nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                nan, nan, nan,
                resolution, nan, cases_male, cases_female,
                nan, nan, nan, nan,
                age_range, age_cases, nan, nan,
                nan, nan, nan,
                nan, nan,
                nan, nan, nan, nan,
                nan, nan])


df = pd.DataFrame(row_csv, columns=columns)
# "Last_Updated" field is not reported all the time so there is a need to fill
# missing data
df[['updated']] = df[['updated']].fillna(method='ffill')
df.to_csv('deleware_.csv', index=False)
