#!/usr/bin/env python3

import requests
import datetime
import os
import pandas as pd
from numpy import nan
from cvpy.static import ColumnHeaders as Headers

country = 'US'
zipcode_cases_url = 'https://services1.arcgis.com/mpVYz37anSdrK4d8/arcgis/rest/services/CVD_ZIPS_FORWEBMAP/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'Arizona'
columns = Headers.updated_site
row_csv = []

# Zip code-level: cases
url = zipcode_cases_url
resolution = 'zipcode'
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
other_keys = ['lower_bound', 'upper_bound']

for feature in raw_data['features']:
    attribute = feature['attributes']
    region = attribute['POSTCODE']
    cases_range_raw = attribute['ConfirmedCaseCount']
    if cases_range_raw != "Data Suppressed":
        cases_range = cases_range_raw.split('-')
        for idx in range(0, len(cases_range)):
            cases = cases_range[idx]
            if len(cases_range) > 1:
                other = 'range'
                other_value = other_keys[idx]
            else:
                other = nan
                other_value = nan
            row_csv.append([
                'state', country, state, region,
                url, str(raw_data), access_time, nan,
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
                other, other_value])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
