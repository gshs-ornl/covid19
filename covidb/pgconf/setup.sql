--() { :: }; exec psql -f "$0"
SET TIME ZONE 'UTC';
CREATE ROLE jesters SUPERUSER LOGIN PASSWORD 'AngryMoose78';
CREATE ROLE reporters LOGIN PASSWORD 'DogFoodIsGood';
CREATE USER cvadmin WITH PASSWORD 'LovingLungfish';
CREATE USER ingester WITH PASSWORD 'AngryMoose' IN ROLE jesters;
CREATE USER digester WITH PASSWORD 'LittlePumpkin' IN ROLE jesters;
CREATE USER librarian WITH PASSWORD 'HungryDeer' IN ROLE reporters;
CREATE USER historian WITH PASSWORD 'SmallGoose' IN ROLE reporters;
CREATE USER guest WITH PASSWORD 'abc123';

SELECT 'CREATE DATABASE covidb WITH OWNER cvadmin'
  WHERE NOT EXISTS (SELECT pg_database WHERE datname = 'covidb');

CREATE SCHEMA IF NOT EXISTS scrape AUTHORIZATION jesters;
CREATE SCHEMA IF NOT EXISTS static AUTHORIZATION jesters, reporters;

ALTER SCHEMA static OWNER TO jesters;

GRANT CONNECT ON DATABASE covidb TO jesters, reporters, guest;

CREATE TABLE IF NOT EXISTS scrape.raw_data (
  country varchar,
  state varchar,
  url varchar,
  raw_page text,
  access_time timestamp,
  county varchar DEFAULT NULL,
  cases integer DEFAULT NULL,
  updated timestamp with time zone,
  deaths integer DEFAULT NULL,
  presumptive integer DEFAULT NULL,
  recovered integer DEFAULT NULL,
  tested integer DEFAULT NULL,
  hospitalized integer DEFAULT NULL,
  negative integer DEFAULT NULL,
  counties integer DEFAULT NULL,
  severe integer DEFAULT NULL,
  lat numeric DEFAULT NULL,
  lon numeric DEFAULT NULL,
  parish varchar DEFAULT NULL,
  monitored integer DEFAULT NULL,
  no_longer_monitored integer DEFAULT NULL,
  pending integer DEFAULT NULL,
  active integer DEFAULT NULL,
  inconclusive integer DEFAULT NULL,
  scrape_group integer NOT NULL
);

CREATE TABLE IF NOT EXISTS static.country (
  id SERIAL PRIMARY KEY,
  iso2c varchar(2),
  iso3c varchar(3),
  country varchar
);

CREATE TABLE IF NOT EXISTS static.state (
  id SERIAL PRIMARY KEY,
  country_id integer REFERENCES static.country(id),
  abb varchar(2),
  state varchar
);

CREATE TABLE IF NOT EXISTS static.county (
  id SERIAL PRIMARY KEY,
  state_id integer REFERENCES static.state(id),
  county_name varchar,
  fips varchar(5),
  alt_name varchar DEFAULT NULL,
  non_std varchar DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS scrape.pages (
  id SERIAL PRIMARY KEY,
  page text,
  url varchar,
  hash varchar(64),
  access_time timestamp with time zone
);

CREATE TABLE IF NOT EXISTS scrape.scrape_group (
  id SERIAL PRIMARY KEY,
  scrape_group integer NOT NULL
);

CREATE TABLE IF NOT EXISTS static.state_data (
  id serial primary key,
  state_id integer REFERENCES static.state(id),
  access_time timestamp,
  updated timestamptz,
  cases integer DEFAULT NULL,
  deaths integer DEFAULT NULL,
  presumptive integer DEFAULT NULL,
  tested integer DEFAULT NULL,
  hospitalized integer DEFAULT NULL,
  negative integer DEFAULT NULL,
  monitored integer DEFAULT NULL,
  no_longer_monitored integer DEFAULT NULL,
  inconclusive integer DEFAULT NULL,
  pending integer DEFAULT NULL,
  scrape_group integer REFERENCES scrape_group(id),
  page_id integer REFERENCES pages(id)
);

CREATE TABLE IF NOT EXISTS scrape.county_data (
  id serial primary key,
  county_id integer REFERENCES static.county(id),
  access_time timestamp,
  updated timestamptz,
  cases integer DEFAULT NULL,
  deaths integer DEFAULT NULL,
  presumptive integer DEFAULT NULL,
  tested integer DEFAULT NULL,
  hospitalized integer DEFAULT NULL,
  negative integer DEFAULT NULL,
  monitored integer DEFAULT NULL,
  no_longer_monitored integer DEFAULT NULL,
  inconclusive integer DEFAULT NULL,
  pending integer DEFAULT NULL,
  scrape_group integer REFERENCES scrape_group(id),
  page_id integer REFERENCES pages(id)
);

CREATE TABLE IF NOT EXISTS static.timezones (
  id serial primary key,
  county_code varchar(2),
  country_name varchar,
  zone_name varchar,
  tz_abb varchar,
  dst boolean,
  utc_offset real
);

CREATE TABLE IF NOT EXISTS static.fips_lut (
  id serial primary key,
  state varchar(2),
  county_name varchar,
  fips varchar(5),
  alt_name varchar
);

CREATE TABLE IF NOT EXISTS static.urls (
  id SERIAL PRIMARY KEY,
  state_id integer REFERENCES static.state(id),
  state varchar,
  url varchar
);

GRANT SELECT ON ALL TABLES IN SCHEMA scraping, static TO reporters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scraping TO jesters;
GRANT SELECT ON ALL TABLES IN SCHEMA static TO jesters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA static TO ingester;
GRANT SELECT ON ALL TABLES IN SCHEMA scraping, static TO guest;
