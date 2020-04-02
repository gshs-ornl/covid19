#!/usr/bin/env python3

import requests
import datetime
import json
from numpy import nan
import pandas as pd
from cvpy.static import Headers


country = 'US'
url = 'https://services.arcgis.com/iFBq2AW9XO0jYYF7/arcgis/rest/services/NCCovid19/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'North Carolina'
resolution = 'county'
columns = Headers.updated_site
row_csv = []

# County level
raw_data = requests.get(url).json()
access_time = datetime.datetime.utcnow()
resolution = 'county'

for feature in raw_data['features']:
    attribute = feature['attributes']
    county = attribute['County']
    cases = attribute['Total']
    deaths = attribute['Deaths']

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, nan, deaths, nan,
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
df = pd.DataFrame(row_csv, columns=columns)
df.to_csv('north_carolina_.csv', index=False)
