create view scraping.vw_all_data as
select ctry.country           as country,
       ctry.iso2c             as iso2c,
       ctry.iso3c             as iso3c,
       s.fips                 as state_fips,
       abb,
       state,
       c.fips                 as county_fips,
       alt_name,
       non_std,
       sd.country_id          as country_id,
       sd.state_id            as state_id,
       sd.access_time         as access_time,
       sd.updated             as updated,
       sd.cases               as cases,
       sd.deaths              as deaths,
       sd.presumptive         as presumptive,
       sd.tested              as tested,
       sd.hospitalized        as hospitalized,
       sd.negative            as negative,
       sd.monitored           as monitored,
       sd.no_longer_monitored as no_longer_monitored,
       sd.inconclusive        as inconclusive,
       sd.pending_tets        as pending_tets,
       sd.scrape_group,
       state_pages.page       as state_page,
       state_pages.url        as state_url,
       state_pages.hash       as state_hash,
       state_pages.access_time as state_access_time,
       c.county_name,
       cd.access_time         as access_time,
       cd.updated             as updated,
       cd.cases               as cases,
       cd.deaths              as deaths,
       cd.presumptive         as presumptive,
       cd.tested              as tested,
       cd.hospitalized        as hospitalized,
       cd.negative            as negative,
       cd.monitored           as monitored,
       cd.no_longer_monitored as no_longer_monitored,
       cd.inconclusive        as inconclusive,
       cd.pending_tets        as pending_tets,
       sg.scrape_group        as scrape_group,
       county_pages.page      as county_page,
       county_pages.url       as county_url,
       county_pages.hash      as county_hash,
       county_pages.access_time as county_access_time,
from static.states s
         join static.county c on c.state_id = c.id
         join static.country ctry ON ctry.id = s.country_id
         join scraping.state_data sd on sd.state_id = s.id
         join scraping.county_data cd on cd.county_id = c.id
         join scraping.scrape_group sg ON sg.scrape_group = sd.scrape_group
         join scraping.pages state_pages ON state_pages.id = sd.page_id
         join scraping.pages county_pages ON county_pages.id = sd.page_id;


create view scraping.vw_state_data as
select ctry.country           as country,
       ctry.iso2c             as iso2c,
       ctry.iso3c             as iso3c,
       s.fips                 as fips,
       abb,
       state,
       sd.access_time         as access_time,
       sd.updated             as updated,
       sd.cases               as cases,
       sd.deaths              as deaths,
       sd.presumptive         as presumptive,
       sd.tested              as tested,
       sd.hospitalized        as hospitalized,
       sd.negative            as negative,
       sd.monitored           as monitored,
       sd.no_longer_monitored as no_longer_monitored,
       sd.inconclusive        as inconclusive,
       sd.pending_tets        as pending_tests,
       sg.scrape_group        as scrape_group,
       page,
       url,
       hash,
       p.access_time          as access_time
from scraping.state_data sd
         join static.states s on sd.state_id = s.id
         join static.country ctry ON ctry.id = s.country_id
         join scraping.scrape_group sg ON sg.scrape_group = sd.scrape_group
         join scraping.pages p ON p.id = sd.page_id;


create view scraping.vw_county_data as
select cd.country_id           as country_id,
       cd.state_id             as state_id,
       county_id               as county_id,
       cd.access_time          as access_time,
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
       pending_tets,
       cd.scrape_group         as scrape_group,
       page_id,
       s.fips                  as state_fips,
       abb,
       state,
       county_name,
       cnt.fips                as country_fips,
       alt_name,
       non_std,
       iso2c,
       iso3c,
       country,
       page,
       url,
       hash,
from scraping.county_data cd
         join scraping.scrape_group sg ON cd.scrape_group = sg.scrape_group
         join scraping.pages p ON p.id = cd.page_id
         join static.states s on cd.state_id = s.id
         join static.county cnt ON cnt.id = cd.county_id
         join static.country c ON c.id = s.country_id;






