create view scraping.vw_state_data as
select ctry.country,
       ctry.iso2c,
       ctry.iso3c,
       s.fips,
       abb,
       state,
       sd.access_time as state_access_time,
       sd.updated,
       sd.cases,
       sd.deaths,
       sd.presumptive,
       sd.tested,
       sd.hospitalized,
       sd.negative,
       sd.monitored,
       sd.no_longer_monitored,
       sd.inconclusive,
       sd.pending_tests,
       sg.scrape_group,
       icu,
       lab,
       lab_tests,
       lab_positive,
       lab_negative,
       age_range,
       age_cases,
       age_percent,
       age_hospitalized,
       age_hospitalized_percent,
       age_deaths,
       age_deaths_percent,
       other,
       other_value
       page,
       url,
       hash,
       p.access_time as page_access_time
from scraping.state_data sd
         join static.states s on sd.state_id = s.id
         join static.country ctry ON ctry.id = s.country_id
         join scraping.scrape_group sg ON sg.scrape_group = sd.scrape_group
         join scraping.pages p ON p.id = sd.page_id;


create view scraping.vw_county_data as
select c.country,
       s.state,
       cd.access_time as county_access_time,
       updated,
       cases,
       deaths,
       presumptive,
       tested,
       hospitalized,
       negative,
       monitored,
       no_longer_monitored,
       inconclusive,
       pending_tests,
       s.fips   as state_fips,
       abb,
       county_name,
       cnt.fips as country_fips,
       alt_name,
       non_std,
       iso2c,
       iso3c,
       sg.scrape_group,
       icu,
       lab,
       lab_tests,
       lab_positive,
       lab_negative,
       age_range,
       age_cases,
       age_percent,
       age_hospitalized,
       age_hospitalized_percent,
       age_deaths,
       age_deaths_percent,
       other,
       other_value
       page,
       url,
       hash,
       p.access_time as page_access_time
from scraping.county_data cd
         join scraping.scrape_group sg ON cd.scrape_group = sg.scrape_group
         join scraping.pages p ON p.id = cd.page_id
         join static.states s on cd.state_id = s.id
         join static.county cnt ON cnt.id = cd.county_id
         join static.country c ON c.id = s.country_id;

GRANT USAGE ON SCHEMA scraping TO guest;
GRANT SELECT ON scraping.vw_county_data TO guest;
GRANT SELECT ON scraping.vw_state_data TO guest;


