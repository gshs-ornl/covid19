import lxml.html as lh
import requests
import datetime
import os
from numpy import nan
import numpy as np
import pandas as pd
from cvpy.static import ColumnHeaders as Headers

country = 'US'
state = 'Oregon'
provider = 'state'
columns = Headers.updated_site
row_csv = []

access_time = datetime.datetime.utcnow()
url = r"https://govstatus.egov.com/OR-OHA-COVID-19#96980fb8-2de5-49c8-98d9-9b437c75bf30"

page = requests.get(url)

doc = lh.fromstring(page.content)

tr_elements = doc.xpath('//tr')
# Create empty list
data = {}
# For each row, store each first element (header) and an empty list
for i in range(1, len(tr_elements)):
    t = tr_elements[i]
    vals = []
    for j in range(len(t)):
        name = t[j].text_content()
        if j == 0:
            col = name
        else:
            vals.append(name)
    data.update({col: vals})

## County data --------------------------------------------------
resolution = 'county'

temp = list(data.items())
start_idx = [idx for idx, key in enumerate(temp) if key[0] == "County"][0]
end_idx = [idx for idx, key in enumerate(temp) if key[0] == "Total"][0]

cols = ["cases", "deaths", "negative", "county"]
df_county = pd.DataFrame(columns=cols)
for i in range(start_idx + 1, end_idx):
    county = list(data.keys())[i]
    d = data[county]
    row = [int(val.replace("%", "")) for val in d]
    row.append(county)
    df = pd.DataFrame([row], columns=cols)
    df_county = df_county.append(df, ignore_index=True)

for county in df_county.county.values:
    cases = df_county[df_county.county == county]["cases"].values[0]
    negative = df_county[df_county.county == county]["negative"].values[0]
    deaths = df_county[df_county.county == county]["deaths"].values[0]

    row_csv.append([
        'state', country, state, nan,
        url, nan, access_time, county,
        cases, nan, deaths, nan,
        nan, nan, nan, negative,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan])
## State basics -------------------------------------------------
resolution = 'state'

cases = int(data["Total cases"][0][:-1].replace(",", ""))
deaths = int(data["Total deaths"][0].replace(",", ""))
positive = int(data["Positive tests"][0].replace(",", ""))
negative = int(data["Negative tests"][0].replace(",", ""))
tested = int(data["Total tested"][0].replace(",", ""))
hospital = int(data["Yes"][0].replace(",", ""))

row_csv.append([
    'state', country, state, nan,
    url, nan, access_time, nan,
    cases, nan, deaths, nan,
    nan, tested, hospital, negative,
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

## State Age Group -----------------------------------------------

temp = list(data.items())
start_idx = [idx for idx, key in enumerate(temp) if key[0] == "Age group"][0]
end_idx = [idx for idx, key in enumerate(temp) if key[0] == "Not available"][0]

cols = ["age_cases", "age_percent", "age_hosp", "age_deaths", "age_range"]
df_age = pd.DataFrame(columns=cols)
for i in range(start_idx + 1, end_idx):
    age_range = list(data.keys())[i]
    d = data[age_range]
    row = [int(val.replace("%", "")) for val in d]
    row.append(age_range)
    df = pd.DataFrame([row], columns=cols)
    df_age = df_age.append(df, ignore_index=True)

for age in df_age.age_range.values:
    age_cases = df_age[df_age.age_range == age]["age_cases"].values[0]
    age_percent = df_age[df_age.age_range == age]["age_percent"].values[0]
    age_deaths = df_age[df_age.age_range == age]["age_deaths"].values[0]
    age_hosp = df_age[df_age.age_range == age]["age_hosp"].values[0]
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
        age, age_cases, age_percent, age_deaths,
        age_hosp, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])

## State Gender -----------------------------------------------

temp = list(data.items())
start_idx = [idx for idx, key in enumerate(temp) if key[0] == "Sex"][0]
end_idx = [idx for idx, key in enumerate(temp) if key[0] == "Hospitalized4"][0]

cols = ["cases", "sex_percent", "deaths", "sex"]
df_sex = pd.DataFrame(columns=cols)
for i in range(start_idx + 1, end_idx):
    gender = list(data.keys())[i]
    d = data[gender]
    row = [int(val.replace("%", "")) for val in d]
    row.append(gender)
    df = pd.DataFrame([row], columns=cols)
    df_sex = df_sex.append(df, ignore_index=True)

for gender in df_sex.sex.values:
    cases = df_sex[df_sex.sex == gender]["cases"].values[0]
    sex_percent = df_sex[df_sex.sex == gender]["sex_percent"].values[0]
    deaths = df_sex[df_sex.sex == gender]["deaths"].values[0]

    if gender == "Female":
        cases_female = cases
        cases_male = nan
    elif gender == "Male":
        cases_female = nan
        cases_male = cases
    else:
        cases_female = nan
        cases_male = nan

    row_csv.append([
        'state', country, state, nan,
        url, nan, access_time, nan,
        cases, nan, deaths, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, cases_male, cases_male,
        nan, nan, nan, nan,
        nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, gender, cases, sex_percent,
        nan, nan])

## State ICU -----------------------------------------------

cols = ["adult_icu_beds_available", "adult_icu_beds_total", "adult_non_icu_beds_available", "adult_non_icu_beds_total",
        "nicu_beds_available", "nicu_beds_total", "non_nicu_beds_available", "non_nicu_beds_total", "ventilators"]

df_icu = pd.DataFrame(columns=["Available", "Total"])

temp = list(data.items())
start_idx = [idx for idx, key in enumerate(temp) if key[0] == "Adult ICU beds"][0]
end_idx = [idx for idx, key in enumerate(temp) if key[0] == "COVID-19 details5"][0]

for i in range(start_idx, end_idx):
    key = list(data.keys())[i]
    d = data[key]
    if key == "Ventilators":
        row = [int(d[0]), nan]
    else:
        row = [int(val.replace("%", "")) for val in d]
    df = pd.DataFrame([row], columns=["Available", "Total"])
    df_icu = df_icu.append(df, ignore_index=True)

# -----------------------------------------------------

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
for i in range(len(cols)):
    df[cols[i]] = nan
df_row = pd.DataFrame([list(np.append([np.repeat(nan, len(columns))], df_icu.values.flatten()[0:9]))],
                      columns=df.keys())
dict_info = {'provider': [provider], 'country': [country], "url": [url],
             "state": [state], "resolution": [resolution], "access_time": [str(access_time)]}
df_row.update(pd.DataFrame.from_dict(dict_info))
df = pd.concat([df, df_row], ignore_index=True)

df.to_csv(file_name, index=False)
