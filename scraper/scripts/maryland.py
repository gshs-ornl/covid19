#!/usr/bin/env python3

import requests
import datetime
from numpy import nan
import pandas as pd
from cvpy.static import Headers


country = 'US'
url = 'https://services.arcgis.com/njFNhDsUCentVYJW/arcgis/rest/services/MD_COVID19_Case_Counts_by_County/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'Maryland'
resolution = 'county'
columns = Headers.updated_site


raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()

row_csv = []

keys_list = ['EOCStatus']

for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['COUNTY']
    cases = attribute['COVID19Cases']
    recovered = attribute['COVID19Recovered']
    deaths = attribute['COVID19Deaths']

    for key in keys_list:
        other = key
        other_value = attribute[key]

        row_csv.append([
            'state', country, state, nan,
            url, str(raw_data), access_time, county,
            cases, nan, deaths, nan,
            recovered, nan, nan, nan,
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


df = pd.DataFrame(row_csv, columns=columns)
df.to_csv('maryland_.csv', index=False)
