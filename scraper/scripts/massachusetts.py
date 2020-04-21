#!/usr/bin/env python3

import datetime
import requests
import os
import pandas as pd
from numpy import nan
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers

country = 'US'
state_url = 'https://www.mass.gov/info-details/covid-19-response-reporting'
state = 'Massachusetts'
columns = Headers.updated_site
row_csv = []

# State-level data
resolution = 'state'
url = state_url
html_text = requests.get(url).text
soup = BeautifulSoup(html_text, 'html.parser')
access_time = datetime.datetime.utcnow()

data = []
for table in soup.find_all('table'):
    for row in table.find_all('tr'):
        cols = [ele.text.strip() for ele in row.find_all('td')]
        if cols:
            data.append(cols[0])

cases = data[0]
quarantine = data[1]
no_longer_monitored = data[2]
monitored = data[3]

row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
        cases, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        monitored, no_longer_monitored, nan,
        nan, nan, quarantine,
        nan, nan, nan,
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
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
