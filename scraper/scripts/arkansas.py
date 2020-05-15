import lxml.html as lh
import requests
import datetime
import os
from numpy import nan
import numpy as np
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
state = 'Arkansas'
provider = 'state'
columns = Headers.updated_site
row_csv = []

access_time = datetime.datetime.utcnow()
url = r"https://www.healthy.arkansas.gov/programs-services/topics/novel-coronavirus"

page = requests.get(url)

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

new_data = {}
for key, val in data.items():
    if len(val) != 0:
        new_data.update({key: val})

resolution = 'state'

## State basics -------------------------------------------------
cases = int(new_data["Confirmed Cases of COVID-19 in Arkansas"][0].replace(",", ""))
hospital = int(new_data["Ever Hospitalized"][0].replace(",", ""))

row_csv.append([
    'state', country, state, nan,
    url, nan, access_time, nan,
    cases, nan, nan, nan,
    nan, nan, hospital, nan,
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

## State Other Vals -------------------------------------------------
cols = ["on_ventilator", "currently_hospitalized", "total_on_ventilator", "nursing_home_cases"]

on_vent = int(new_data["Currently on Ventilator"][0].replace(",", ""))
current_hosp = int(new_data["Currently Hospitalized"][0].replace(",", ""))
tot_vent = int(new_data["Ever on Ventilator"][0].replace(",", ""))
nursing_home = int(new_data["Total Nursing Home Residents"][0].replace(",", ""))

vals = [on_vent, current_hosp, tot_vent, nursing_home]

## State by Gender -------------------------------------------------
gender_data = new_data["Gender"][0].rsplit("\n\t\t\t")

for i in range(len(gender_data)):
    d = gender_data[i].split("=")
    sex = d[0].strip()
    sex_percent = float(d[1].strip().replace("%", ""))
    row_csv.append([
        'state', country, state, nan,
        url, nan, access_time, nan,
        nan, nan, nan, nan,
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
        nan, sex, nan, sex_percent,
        nan, nan])

## State by Race -------------------------------------------------
race_data = new_data["Race"][0].rsplit("\n\t\t\t")

for i in range(len(race_data)):
    d = race_data[i].split(":")
    race = d[0].strip()
    race_cases = int(d[1].strip().replace(",", ""))
    row_csv.append([
        'state', country, state, nan,
        url, nan, access_time, nan,
        race_cases, nan, nan, nan,
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
        "race", race])

## State by Age -------------------------------------------------
age_data = new_data["Age"][0].rsplit("\n\t\t\t")

for i in range(len(age_data)):
    d = age_data[i].split(":")
    age = d[0].strip()
    age_cases = int(d[1].strip().replace(",", ""))
    row_csv.append([
        'state', country, state, nan,
        url, nan, access_time, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age, age_cases, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
for i in range(len(cols)):
    df[cols[i]] = nan
df_row = pd.DataFrame([list(np.append([np.repeat(nan, len(columns))], vals))], columns=df.keys())
dict_info = {'provider': [provider], 'country': [country], "url": [url],
             "state": [state], "resolution": [resolution], "access_time": [str(access_time)]}
df_row.update(pd.DataFrame.from_dict(dict_info))
df = pd.concat([df, df_row], ignore_index=True)

df.to_csv(file_name, index=False)
