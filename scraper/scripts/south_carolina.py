#!/usr/bin/env python3

import requests
import datetime
import os
from numpy import nan
import pandas as pd
from cvpy.static import ColumnHeaders as Headers
from cvpy.url_helpers import determine_updated_timestep
import lxml.html as lh

country = 'US'
url = 'https://services2.arcgis.com/XZg2efAbaieYAXmu/arcgis/rest/services/COVID19/FeatureServer/0//query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=4326&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=standard&f=pjson&token='
state = 'South Carolina'
resolution = 'county'
columns = Headers.updated_site

other_keys_county = ['County_Rate']

response = requests.get(url)
access_time = datetime.datetime.utcnow()
updated = determine_updated_timestep(response)
raw_data = response.json()

row_csv = []
state_cases = []
state_deaths = []

for feature in raw_data['features']:
    attribute = feature['attributes']

    county = attribute['NAME']
    cases = attribute['Confirmed']
    recovered = attribute['Recovered']
    deaths = attribute['Death']

    other = 'County_Rate'
    other_value = attribute[other]

    state_cases.append(int(cases))
    state_deaths.append(int(deaths))

    row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, county,
        cases, updated, deaths, nan,
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

# State-level data
resolution = 'state'
cases = sum(state_cases)
deaths = sum(state_deaths)
row_csv.append([
        'state', country, state, nan,
        url, str(raw_data), access_time, nan,
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
    nan, nan])

url_table = r"https://scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-testing-data-projections-covid-19"
page = requests.get(url_table)
doc = lh.fromstring(page.content)
tr_elements = doc.xpath('//tr')
# Create empty list
data = {}
# For each row, store each first element (header) and an empty list
for i in range(0, len(tr_elements)):
    t = tr_elements[i]
    vals = []
    for j in range(len(t)):
        name = t[j].text_content()
        if j == 0:
            col = name
        else:
            vals.append(name)
    data.update({col: vals})

total = int(data["Total number of tests performed in South Carolina"][0].replace(",", ""))
pos = int(data["Total positive tests"][0].replace(",", ""))
neg = int(data["Total negative tests"][0].replace(",", ""))
private_tests = int(data["Negative tests from private laboratories"][0].replace(",", "")) + int(
    data["Positive tests from private laboratories"][0].replace(",", ""))
state_tests = int(data["Negative tests from DHEC Public Health Laboratory"][0].replace(",", "")) + int(
    data["Positive tests from DHEC Public Health Laboratory"][0].replace(",", ""))

# State-level data
resolution = 'state'
row_csv.append([
    'state', country, state, nan,
    url_table, nan, access_time, nan,
    nan, updated, nan, nan,
    nan, total, nan, neg,
    nan, nan, nan, nan, nan,
    nan, nan, nan,
    nan, nan, nan,
    private_tests, state_tests, nan,
    resolution, nan, nan, nan,
    nan, nan, nan, nan,
    nan, nan, nan, nan,
    nan, nan, nan,
    nan, nan,
    nan, nan, nan, nan,
    nan, nan])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
if path and not path.endswith('/'):
    path += '/'
file_name = path + state.replace(' ', '_') + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
