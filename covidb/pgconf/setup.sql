--() { :: }; exec psql -f "$0"
SET TIME ZONE 'UTC';
CREATE ROLE jesters SUPERUSER LOGIN PASSWORD 'AngryMoose78';
CREATE ROLE reporters LOGIN PASSWORD 'DogFoodIsGood';
CREATE USER cvadmin WITH CREATEDB CREATEROLE PASSWORD 'LovingLungfish';
CREATE USER ingester WITH PASSWORD 'AngryMoose' IN ROLE jesters;
CREATE USER digester WITH PASSWORD 'LittlePumpkin' IN ROLE jesters;
CREATE USER librarian WITH PASSWORD 'HungryDeer' IN ROLE reporters;
CREATE USER historian WITH PASSWORD 'SmallGoose' IN ROLE reporters;
CREATE USER guest WITH PASSWORD 'abc123';
CREATE DATABASE covidb WITH OWNER cvadmin;

 GRANT CONNECT ON DATABASE covidb TO ingester, digester, librarian, historian,guest;
\c covidb
DROP SCHEMA if exists static;
CREATE SCHEMA static AUTHORIZATION jesters
   CREATE TABLE IF NOT EXISTS timezones
     (county_code varchar(2), country_name varchar, zone_name varchar,
      tz_abb text, dst boolean, _offset real)
   CREATE TABLE IF NOT EXISTS fips_lut
     (state varchar(2), county_name varchar, fips varchar(5), alt_name varchar)
   CREATE TABLE IF NOT EXISTS country
     (id SERIAL PRIMARY KEY, iso2c varchar(2), iso3c varchar(3),
      country varchar)
   CREATE TABLE IF NOT EXISTS states
     (id SERIAL PRIMARY KEY, country_id int REFERENCES static.country(id), abb varchar(2), state varchar)
   CREATE TABLE IF NOT EXISTS urls
     (state_id int REFERENCES static.states(id), state varchar, url varchar)
   CREATE TABLE IF NOT EXISTS county
     (id SERIAL PRIMARY KEY, county_name varchar,
      state_id integer REFERENCES static.states(id),
      fips varchar(5), alt_name varchar DEFAULT NULL,
      non_std varchar DEFAULT NULL);

DROP SCHEMA if exists scraping;
 CREATE SCHEMA scraping AUTHORIZATION jesters
   CREATE TABLE IF NOT EXISTS raw_data
   (country varchar, state varchar, url varchar, raw_page text,
    access_time timestamp, county varchar DEFAULT NULL,
    cases integer DEFAULT NULL, udpated timestamp with time zone,
    deaths integer DEFAULT NULL, presumptive integer DEFAULT NULL,
    recovered integer DEFAULT NULL, tested integer DEFAULT NULL,
    hospitalized integer DEFAULT NULL, negative integer DEFAULT NULL,
    counties integer DEFAULT NULL, severe integer DEFAULT NULL,
    lat numeric DEFAULT NULL, lon numeric DEFAULT NULL,
    parish varchar DEFAULT NULL, monitored integer DEFAULT NULL,
    no_longer_monitored integer DEFAULT NULL,
    pending_tests integer DEFAULT NULL, active integer DEFAULT NULL,
    inconclusive integer DEFAULT NULL, scrape_group integer NOT NULL)
  CREATE TABLE IF NOT EXISTS pages
   (id SERIAL PRIMARY KEY, page text, url varchar, hash varchar(64),
    access_time timestamp with time zone)
  CREATE TABLE IF NOT EXISTS scrape_group
   (id SERIAL PRIMARY KEY, scrape_group integer NOT NULL)
  CREATE TABLE IF NOT EXISTS pages
   (id SERIAL PRIMARY KEY, url varchar NOT NULL, page text NOT NULL,updated timestamp with time zone)
  CREATE TABLE IF NOT EXISTS state_data
   (country_id integer REFERENCES static.country(id),
    state_id integer REFERENCES static.states(id),
    access_time timestamp, updated timestamp with time zone,
    cases integer DEFAULT NULL, deaths integer DEFAULT NULL,
    presumptive integer DEFAULT NULL, tested integer DEFAULT NULL,
    hospitalized integer DEFAULT NULL, negative integer DEFAULT NULL,
    monitored integer DEFAULT NULL, no_longer_monitored integer DEFAULT NULL,
    inconclusive integer DEFAULT NULL, pending_tets integer DEFAULT NULL,
    scrape_group  integer REFERENCES scraping.scrape_group(id), page_id integer REFERENCES pages(id))
  CREATE TABLE IF NOT EXISTS county_data
   (country_id integer REFERENCES static.country(id),
    state_id integer REFERENCES static.states(id),
    county_id integer REFERENCES static.county(id),
    access_time timestamp, updated timestamp with time zone,
    cases integer DEFAULT NULL, deaths integer DEFAULT NULL,
    presumptive integer DEFAULT NULL, tested integer DEFAULT NULL,
    hospitalized integer DEFAULT NULL, negative integer DEFAULT NULL,
    monitored integer DEFAULT NULL, no_longer_monitored integer DEFAULT NULL,
    inconclusive integer DEFAULT NULL, pending_tets integer DEFAULT NULL,
    scrape_group integer REFERENCES scraping.scrape_group(id), page_id integer REFERENCES pages(id)
  )

GRANT USAGE ON SCHEMA scraping TO reporters, jesters;
GRANT SELECT ON ALL TABLES IN SCHEMA scraping,static TO reporters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scraping TO jesters;
GRANT SELECT ON ALL TABLES IN SCHEMA static TO jesters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA static TO ingester;

