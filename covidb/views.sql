
/*
create view scraping.vw_all_data as
select ctry.country,
       ctry.iso2c,
       ctry.iso3c,
       s.fips,
       abb,
       state,
       c.fips,
       alt_name,
       non_std,
       sd.country_id,
       sd.state_id,
       sd.access_time         as state_access_time,
       sd.updated             as state_updated,
       sd.cases               as state_cases,
       sd.deaths              as state_deaths,
       sd.presumptive         as state_presumptive,
       sd.tested              as state_tested,
       sd.hospitalized        as state_hospitalized,
       sd.negative            as state_negative,
       sd.monitored           as state_monitored,
       sd.no_longer_monitored as state_no_longer_monitored,
       sd.inconclusive        as state_inconclusive,
       sd.pending_tests        as state_pending_tets,
       sd.scrape_group,
       sd.icu as state_icu,
       sd.lab as state_lab,
       sd.lab_tests as state_lab_tests,
       sd.lab_positive as state_lab_positive,
       sd.lab_negative as state_lab_negative,
       sd.age_range as state_age_range,
       sd.age_cases as state_age_cases,
       sd.age_percent as state_age_percent,
       sd.age_hospitalized as state_hospitalized,
       sd.age_hospitalized_percent as state_age_hospitalized_percent,
       sd.age_deaths as state_age_deaths,
       sd.age_deaths_percent as state_age_deaths_percent,
       sd.other as state_other,
       sd.other_value as state_other_value,
       state_pages.page as state_page,
       state_pages.url as state_url,
       state_pages.hash as state_hash,
       state_pages.access_time as state_access_time,
       c.county_name,
       cd.access_time         as county_access_time,
       cd.updated             as county_updated,
       cd.cases               as county_cases,
       cd.deaths              as county_deaths,
       cd.presumptive         as county_presumptive,
       cd.tested              as county_tested,
       cd.hospitalized        as county_hospitalized,
       cd.negative            as county_negative,
       cd.monitored           as county_monitored,
       cd.no_longer_monitored as county_no_longer_monitored,
       cd.inconclusive        as county_inconclusive,
       cd.pending_tests        as county_pending_tests,
       sg.scrape_group,
       county_pages.page as county_page,
       county_pages.url as county_url,
       county_pages.hash as county_hash,
       county_pages.access_time as county_access_time,
       cd.icu as county_icu,
       cd.lab as county_lab,
       cd.lab_tests as county_lab_tests,
       cd.lab_positive as county_lab_positive,
       cd.lab_negative as county_lab_negative,
       cd.age_range as county_age_range,
       cd.age_cases as county_age_cases,
       cd.age_percent as county_age_percent,
       cd.age_hospitalized as county_hospitalized,
       cd.age_hospitalized_percent as county_age_hospitalized_percent,
       cd.age_deaths as county_age_deaths,
       cd.age_deaths_percent as county_age_deaths_percent,
       cd.other as county_other,
       cd.other_value as county_other_value
from static.states s
         join static.county c on c.state_id = c.state_id
         join static.country ctry ON ctry.id = s.country_id
         join scraping.state_data sd on sd.state_id = s.id
         join scraping.county_data cd on cd.county_id = c.id
         join scraping.scrape_group sg ON sg.scrape_group = sd.scrape_group
         join scraping.pages state_pages ON state_pages.id = sd.page_id
         join scraping.pages county_pages ON county_pages.id = sd.page_id;
*/

create view scraping.vw_state_data as
select ctry.country,
       ctry.iso2c,
       ctry.iso3c,
       s.fips,
       abb,
       state,
       sd.access_time,
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
       p.access_time
from scraping.state_data sd
         join static.states s on sd.state_id = s.id
         join static.country ctry ON ctry.id = s.country_id
         join scraping.scrape_group sg ON sg.scrape_group = sd.scrape_group
         join scraping.pages p ON p.id = sd.page_id;



create view scraping.vw_county_data as
select cd.country_id,
       cd.state_id,
       county_id,
       cd.access_time,
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
       cd.scrape_group,
       page_id,
       s.fips   as state_fips,
       abb,
       state,
       county_name,
       cnt.fips as country_fips,
       alt_name,
       non_std,
       iso2c,
       iso3c,
       country,
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
       p.access_time
from scraping.county_data cd
         join scraping.scrape_group sg ON cd.scrape_group = sg.scrape_group
         join scraping.pages p ON p.id = cd.page_id
         join static.states s on cd.state_id = s.id
         join static.county cnt ON cnt.id = cd.county_id
         join static.country c ON c.id = s.country_id;






