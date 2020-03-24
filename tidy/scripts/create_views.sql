--() { :: }; exec psql -f "$0"
DROP VIEW IF EXISTS scraping.vw_county_data;
CREATE VIEW scraping.vw_county_data AS
  SELECT country, state, county, access_time, updated, group_scrape, cases,
         deaths, presumptive, tested, hospitalized, negative, monitored,
         no_longer_monitored, inconclusive, pending, scrape_group, page_id
        FROM scraping.county_data c
  JOIN static.country cn ON cn.id == c.country_id
  JOIN static.states st ON st.id == c.state_id
  JOIN static.county as ct ON ct.id == c.county_id;

DROP VIEW IF EXISTS scraping.vw_state_data;
CREATE VIEW scraping.vw_state_data AS
  SELECT country, state, county, access_time, updated, group_scrape, cases,
         deaths, presumptive, tested, hospitalized, negative, monitored,
         no_longer_monitored, inconclusive, pending, scrape_group, page_id,
         counties
        FROM scraping.state_data sd
  JOIN static.country cn ON cn.id == sd.country_id
  JOIN static.states st ON st.id == sd.state_id;
