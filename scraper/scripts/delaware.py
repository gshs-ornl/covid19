#!/usr/bin/env python3

import requests
import datetime
from numpy import nan
import pandas as pd


country = 'US'
url = 'https://services1.arcgis.com/PlCPCPzGOwulHUHo/ArcGIS/rest/services/DEMA_COVID_County_Boundary_Time_VIEW/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryPoint&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson&token='
state = 'Delaware'
resolution = 'county'
columns = ['country', 'state', 'url', 'raw_page', 'access_time', 'county',
           'cases', 'updated', 'deaths', 'presumptive', 'recovered', 'tested',
           'hospitalized', 'negative', 'counties', 'severe', 'lat', 'lon',
           'parish', 'monitored', 'private_test', 'state_test',
           'no_longer_monitored', 'pending_tests', 'active', 'inconclusive',
           'scrape_group', 'icu',
           'cases_0_9', 'cases_10_19', 'cases_20_29', 'cases_30_39',
           'cases_40_49', 'cases_50_59', 'cases_60_69', 'cases_70_79',
           'cases_80',
           'hospitalized_0_9', 'hospitalized_10_19', 'hospitalized_20_29',
           'hospitalized_30_39', 'hospitalized_40_49', 'hospitalized_50_59',
           'hospitalized_60_69', 'hospitalized_70_79', 'hospitalized_80',
           'deaths_0_9', 'deaths_10_19', 'deaths_20_29', 'deaths_30_39',
           'deaths_40_49', 'deaths_50_59', 'deaths_60_69', 'deaths_70_79',
           'deaths_80']


raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

row_csv = []

for feature in raw_data['features']:
    attribute = feature['attributes']
    if attribute["TYPE"] == 'mainland' and attribute['NAME'] != 'Statewide':
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

        row_csv.append([country, state, url, str(raw_data), access_time, county,
           cases, updated, deaths, nan, recovered, nan,
           hospitalized, negative_tests, nan, nan, nan, nan,
           nan,  nan, nan, nan,
           nan, nan, nan, nan,
           nan, nan,
           nan, nan, nan, nan,
           nan, nan, nan, nan,
           nan,
           nan, nan, nan,
           nan, nan, nan,
           nan, nan, nan,
           nan, nan, nan, nan,
           nan, nan, nan, nan, nan])


df = pd.DataFrame(row_csv, columns=columns)
# "Last_Updated" field is not reported all the time so there is a need to fill
# missing data
df[['updated']] = df[['updated']].fillna(method='ffill')
df.to_csv('deleware_.csv', index=False)
