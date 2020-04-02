\c covidb


create view scraping.vw_country_data as
    select ctry.country,
       provider,
       region,
       u.url,
       cd.access_time as country_access_time,
       cases,
       updated,
       deaths,
       presumptive,
       recovered,
       tested,
       hospitalized,
       negative,
       counties,
       severe,
       lat,
       lon,
       monitored,
       no_longer_monitored,
       pending,
       active,
       inconclusive,
       quarantined,
       scrape_group_id,
       resolution,
       icu,
       cases_male,
       cases_female,
       lab,
       lab_tests,
       lab_positive,
       lab_negative,
           a.age_ranges
       age_cases,
       age_percent,
       age_deaths,
       age_hospitalized,
       age_tested,
       age_negative,
       age_hospitalized_percent,
       age_negative_percent,
       age_deaths_percent,
       sex,
       sex_counts,
       sex_percent,
           sex_death,
       other,
       other_value,
       sg.scrape_group
from scraping.country_data cd
         join static.country ctry ON ctry.id = cd.country_id
         join scraping.scrape_group sg ON sg.id = cd.scrape_group_id
         join scraping.pages p ON p.id = cd.page_id
         join static.urls u ON u.id = cd.url_id
         join scraping.age_ranges a ON a.id = cd.age_range;


create view scraping.vw_state_data as
select ctry.country,
       s.state,
       provider,
       region,
       u.url,
       sd.access_time as state_access_time,
       cases,
       updated,
       deaths,
       presumptive,
       recovered,
       tested,
       hospitalized,
       negative,
       counties,
       severe,
       lat,
       lon,
       monitored,
       no_longer_monitored,
       pending,
       active,
       inconclusive,
       quarantined,
       scrape_group_id,
       resolution,
       icu,
       cases_male,
       cases_female,
       lab,
       lab_tests,
       lab_positive,
       lab_negative,
           a.age_ranges
       age_cases,
       age_percent,
       age_deaths,
       age_hospitalized,
       age_tested,
       age_negative,
       age_hospitalized_percent,
       age_negative_percent,
       age_deaths_percent,
       sex,
       sex_counts,
       sex_percent,
       sex_death,
       other,
       other_value,
       sg.scrape_group
from scraping.state_data sd
         join static.states s on sd.state_id = s.id
         join static.country ctry ON ctry.id = s.country_id
         join scraping.scrape_group sg ON sg.id = sd.scrape_group_id
         join scraping.pages p ON p.id = sd.page_id
         join static.urls u ON u.id = sd.url_id
         join scraping.age_ranges a On a.id = sd.age_range;


create view scraping.vw_county_data as
select ctry.country,
       s.state,
       c.county_name,
       provider,
       region,
       u.url,
       cd.access_time as county_access_time,
       cases,
       updated,
       deaths,
       presumptive,
       recovered,
       tested,
       hospitalized,
       negative,
       counties,
       severe,
       lat,
       lon,
       monitored,
       no_longer_monitored,
       pending,
       active,
       inconclusive,
       quarantined,
       scrape_group_id,
       resolution,
       icu,
       cases_male,
       cases_female,
       lab,
       lab_tests,
       lab_positive,
       lab_negative,
       a.age_ranges,
       age_cases,
       age_percent,
       age_deaths,
       age_hospitalized,
       age_tested,
       age_negative,
       age_hospitalized_percent,
       age_negative_percent,
       age_deaths_percent,
       sex,
       sex_counts,
       sex_percent,
       sex_death,
       other,
       other_value,
       sg.scrape_group
from scraping.county_data cd
         join static.fips_lut f ON f.id = cd.fips_id
         join static.county c ON c.id = f.county_id
         join static.states s on s.id = f.state_id
         join static.country ctry ON ctry.id = s.country_id
         join scraping.scrape_group sg ON sg.id = cd.scrape_group_id
         join scraping.pages p ON p.id = cd.page_id
         join static.urls u ON u.id = cd.url_id
         join scraping.age_ranges a On a.id = cd.age_range;


GRANT USAGE ON SCHEMA scraping TO guest;
GRANT SELECT ON scraping.vw_country_data TO guest;
GRANT SELECT ON scraping.vw_county_data TO guest;
GRANT SELECT ON scraping.vw_state_data TO guest;


