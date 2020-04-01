#!/usr/bin/env python3

import requests
import datetime
from numpy import nan
import pandas as pd
from cvpy.static import Headers


country = 'US'
url = 'https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_COVID19_Cases/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'Florida'
resolution = 'county'
columns = Headers.updated_site


raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

row_csv = []
keys_used = ['County_1','C_FLRes', 'C_NotFLRes', 'C_Hosp_Yes',
             'T_NegRes', 'T_NegNotFLRes', 'TPending',
             'OBJECTID_12_13', 'OBJECTID', 'OBJECTID_1', 'DEPCODE',
             'COUNTY', 'COUNTYNAME', 'DATESTAMP', 'ShapeSTAre',
             'ShapeSTLen', 'OBJECTOD_1', 'State', 'OBJECTID_12',
             'DEPCODE_1', 'COUNTYN', 'Shape__Area', 'Shape__Length']

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County_1']
    if county != 'Unknown':
        # Get FL Resident and non-resident in FL
        cases = attribute['C_FLRes'] + attribute['C_NotFLRes']
        deaths = attribute['Deaths']
        hospitalized = attribute['C_Hosp_Yes']
        negative_tests = attribute['T_NegRes'] + attribute['T_NegNotFLRes']
        pending = attribute['TPending']
        key_list = attribute.keys()
        for key in key_list:
            if key not in keys_used:
                other = key
                other_value = attribute[key]
                row_csv.append([
                    'state', country, state, nan,
                    url, str(raw_data), access_time, county,
                    cases, nan, deaths, nan,
                    nan, nan, nan, negative_tests,
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


df = pd.DataFrame(row_csv, columns=Headers.updated_site)
df.to_csv('florida_.csv', index=False)
