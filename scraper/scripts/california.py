#!/usr/bin/env python3

import requests
import datetime
import os
import re
from numpy import nan
import pandas as pd
from bs4 import BeautifulSoup
from cvpy.static import ColumnHeaders as Headers
from cvpy.ocr import ReadImage

country = 'US'
url = 'https://www.cdph.ca.gov/Programs/CID/DCDC/Pages/Immunization/ncov2019.aspx'
state = 'California'
resolution = 'state'
columns = Headers.updated_site

html_text = requests.get(url).text
soup = BeautifulSoup(html_text, "html5lib")
access_time = datetime.datetime.utcnow()

placeholder_url = 'https://www.cdph.ca.gov/Programs'
imgs = soup.find_all('img')
for img in imgs:
    img_src = img['src']
    if 'CA_COVID-19' in img_src:
        state_cases_url = img_src.replace('/Programs', placeholder_url)
    elif 'Demographics' in img_src:
        state_demo_url = img_src.replace('/Programs', placeholder_url)


row_csv = []

read_img = ReadImage(state_cases_url)
state_image_df = ReadImage.process(read_img)

# Parsing info for first image - state cases
age_group_row_nums = [53, 61, 69, 77, 83]
gender_row_nums = [56, 64, 72]
confirmed_hospitalized_info = state_image_df.iloc[93]['text'].split('/')
suspected_hospitalized_info = state_image_df.iloc[94]['text'].split('/')

other_list = ['confirmed COVID-19 in ICU',
              'suspected COVID-19 hospitalized', 'suspected COVID-19 in ICU']
other_value_list = [confirmed_hospitalized_info[1],
               suspected_hospitalized_info[0], suspected_hospitalized_info[1]]

cases = int((state_image_df.iloc[30]['text']).replace(',', ''))
hospitalized = confirmed_hospitalized_info[0]
deaths = state_image_df.iloc[95]['text']

for age_group_row_num in age_group_row_nums:
    age_range = state_image_df.iloc[age_group_row_num]['text'].replace(':', '')
    age_cases = int(
        state_image_df.iloc[age_group_row_num + 1]['text'].replace(',', ''))

    row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
        cases, nan, deaths, nan,
        nan, nan, nan, nan,
        nan, nan, nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        nan, nan, nan,
        resolution, nan, nan, nan,
        nan, nan, nan, nan,
        age_range, age_cases, nan, nan,
        nan, nan, nan,
        nan, nan,
        nan, nan, nan, nan,
        nan, nan])

for gender_row_num in gender_row_nums:
    sex = state_image_df.iloc[gender_row_num]['text'].replace(':', '')
    sex_counts = int(
        state_image_df.iloc[gender_row_num + 1]['text'].replace(',', ''))
    row_csv.append([
        'state', country, state, nan,
        url, str(html_text), access_time, nan,
        cases, nan, deaths, nan,
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
        nan, sex, sex_counts, nan,
        nan, nan])

if len(other_list) == len(other_value_list):
    for idx in range(0, len(other_list)):
        other = other_list[idx]
        other_value = other_value_list[idx]
        row_csv.append([
            'state', country, state, nan,
            url, str(html_text), access_time, nan,
            cases, nan, deaths, nan,
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
else:
    print("The lengths for other keys and values are not equal")


read_img = ReadImage(state_demo_url)
demo_image_df = ReadImage.process(read_img)

# Parsing info for second image - demographics
race_list = [70, 75, 80, [85, 86, 89], 94,
             [99, 100, 101, 104, 105], [110, 111, 112, 119, 120], 124]
percent_list = ['percent_cases', 'percent_deaths', 'percent_CA_population']
percent_list_rows = [70, 75, 80, 89, 94, 105, 112, 124]

for race_row in race_list:
    index = race_list.index(race_row)
    if type(race_row) == list:
        race_name_list = []
        for row in race_row:
            race_name_list.append(demo_image_df.iloc[row]['text'])
        race_name = "_".join(race_name_list)
    else:
        race_name = demo_image_df.iloc[race_row]['text']

    count = 1
    for each_percent in percent_list:
        focused_row = percent_list_rows[index]
        other = race_name + '_' + each_percent
        other_value_raw = str(
            demo_image_df.iloc[focused_row + count]['text'])
        other_value = re.sub(r'(l|\[|\])', '1', other_value_raw)
        count = count + 1

        row_csv.append([
            'state', country, state, nan,
            url, str(html_text), access_time, nan,
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
            nan, nan, nan, nan,
            other, other_value])

now = datetime.datetime.now()
dt_string = now.strftime("_%Y-%m-%d_%H%M")
path = os.getenv("OUTPUT_DIR", "")
file_name = path + state + dt_string + '.csv'

df = pd.DataFrame(row_csv, columns=columns)
df.to_csv(file_name, index=False)
