--() { :: }; exec psql -f "$0"
-- =============================================
-- Author:      Bryan Eaton and Josh Grant
-- Create date:  3/27/2020
-- Description: Init sql for creating database
--              objects for the Covid Scraper project.
-- =============================================


SET TIME ZONE 'UTC';
CREATE ROLE jesters SUPERUSER LOGIN PASSWORD 'AngryMoose78';
CREATE ROLE reporters LOGIN PASSWORD 'DogFoodIsGood';
CREATE USER cvadmin WITH CREATEDB CREATEROLE SUPERUSER PASSWORD 'LovingLungfish';
CREATE USER ingester WITH PASSWORD 'AngryMoose' IN ROLE jesters; -- INGEST TO RAW DATA SOURCES
CREATE USER digester WITH PASSWORD 'LittlePumpkin' IN ROLE jesters; -- raw CSV
CREATE USER librarian WITH PASSWORD 'HungryDeer' IN ROLE reporters; -- updating static tables
CREATE USER historian WITH PASSWORD 'SmallGoose' IN ROLE reporters; -- mostly read-only
CREATE USER guest WITH PASSWORD 'abc123';
SELECT 'CREATE DATABASE covidb WITH OWNER cvadmin'
WHERE NOT EXISTS(SELECT FROM pg_database WHERE datname = 'covidb')
\gexec

GRANT CONNECT ON DATABASE covidb TO ingester, digester, librarian, historian,
    guest;
\c covidb
CREATE EXTENSION pgcrypto;
CREATE SCHEMA IF NOT EXISTS static AUTHORIZATION jesters;
CREATE TABLE IF NOT EXISTS static.timezones
(
    county_code  varchar(2),
    country_name varchar,
    zone_name    varchar,
    tz_abb       text,
    dst          boolean,
    _offset      real
);
/****FIXME why is this also not mapped to state and county tables? ****/
CREATE TABLE IF NOT EXISTS static.country
 (id SERIAL PRIMARY KEY,
  iso2c varchar(2),
  iso3c varchar(3),
  country varchar,
CONSTRAINT const_country UNIQUE (country));
CREATE TABLE IF NOT EXISTS static.states
(
    id         SERIAL PRIMARY KEY,
    country_id int REFERENCES static.country (id),
    fips       varchar(2),
    abb        varchar(2),
    state      varchar,
    CONSTRAINT const_states UNIQUE (state)
);

CREATE TABLE IF NOT EXISTS static.county
(
    id          SERIAL PRIMARY KEY,
    county_name varchar,
    state_id    integer REFERENCES static.states (id),
    country_id int REFERENCES static.country (id),
    fips        varchar(5),
    alt_name    varchar DEFAULT NULL,
    non_std     varchar DEFAULT NULL
);
ALTER TABLE static.county
    ADD CONSTRAINT const_county_unique UNIQUE (county_name, state_id);

/****FIXME why was this county_code? changed to country_code, why is this not
 mapped to the country or state(contains provinces) table? -- jng ****/
CREATE TABLE IF NOT EXISTS static.fips_lut
 (id serial PRIMARY KEY ,
  state_id integer REFERENCES static.states(id),
  county_id integer REFERENCES static.county(id),
  fips varchar(5),
  alt_name varchar);

create table  if not exists static.geounits (
    id serial PRIMARY KEY,
    county_id int references static.county(id),
    state_id int references static.states(id),
    country_id int references static.country(id)
	, name TEXT
    , resolution TEXT -- country, state, county, etc.
    , details TEXT
    , meta JSONB
);

CREATE TABLE IF NOT EXISTS static.urls
(
    id serial primary key ,
    state_id int REFERENCES static.states (id),
    state    varchar,
    url      varchar,
    CONSTRAINT cons_url UNIQUE (url)
);

CREATE SCHEMA IF NOT EXISTS scraping AUTHORIZATION jesters;

CREATE TABLE IF NOT EXISTS scraping.age_ranges
(
    id         SERIAL PRIMARY KEY,
    age_ranges varchar,
    CONSTRAINT cons_url UNIQUE (age_ranges)
);



--"Melt" Tables

CREATE TABLE IF NOT EXISTS scraping.attribute_classes
 (
  id SERIAL PRIMARY KEY,
  name varchar NOT NULL,
  units varchar,
  class varchar
);

CREATE TABLE IF NOT EXISTS scraping.attributes
 (id SERIAL PRIMARY KEY,
  attribute varchar NOT NULL
);

create table scraping.providers
(
	id serial not null
		constraint provider_pkey
			primary key,
	provider_abb text UNIQUE,
	provider_name text
);

CREATE TABLE IF NOT EXISTS scraping.vendors (
    id serial PRIMARY KEY ,
    name text UNIQUE,
    details text
);

CREATE TABLE if not exists  scraping.datasets (
    id serial PRIMARY KEY ,
	vendor_id int REFERENCES scraping.vendors(id)
	, name TEXT DEFAULT 'FIXME: replace this autogenerated text'
	, details TEXT
    ,UNIQUE (vendor_id, name));

CREATE TABLE if not exists scraping.scrapes (
      id SERIAL PRIMARY KEY
    , provider_id int REFERENCES scraping.providers(id)
	, dataset_id int REFERENCES scraping.datasets(id)
    , uri TEXT
    , scraped_ts TIMESTAMP WITH TIME ZONE
    , doc TEXT
    , csv_file TEXT -- source CSV file
    , csv_row INT -- row in the CSV file
    ,UNIQUE (provider_id, uri, scraped_ts));

CREATE TABLE IF NOT EXISTS scraping.melt
(
  dataset_id int references scraping.datasets(id),
  geounit_id int references static.geounits(id),
  updated timestamp with time zone NOT NULL,
  scrape_id integer REFERENCES scraping.scrapes(id),
  attribute_class integer REFERENCES scraping.attribute_classes(id),
  attribute integer REFERENCES scraping.attributes(id),
  value numeric NOT NULL
);

\set myschema staging
\i setup-staging.sql

create or replace function :myschema.get_provider(v_provider text) RETURNS int
    language plpgsql
as
$$
DECLARE _result text := (select provider_id from staging.provider where name = v_provider);
BEGIN
    IF _result is null then
        INSERT INTO staging.provider (name) values (v_provider) RETURNING provider_id into _result;
    end if;
    return _result;
end;
$$;

create or replace function :myschema.get_vendor(v_vendor text) RETURNS int
    language plpgsql
as
$$
DECLARE _result text := (select vendor_id from staging.vendors where name = v_vendor);
BEGIN
    IF _result is null then
        INSERT INTO staging.vendors (name) values (v_vendor) RETURNING vendor_id into _result;
    end if;
    return _result;
end;
$$;

create or replace function :myschema.save_geounit(v_geounit text, v_resolution text) returns void
    language plpgsql
as
$$

BEGIN
    INSERT INTO staging.geounits (geounit_id, resolution)
    values (v_geounit, v_resolution)
    ON CONFLICT DO NOTHING;
end;
$$;

create or replace function :myschema.get_scrape(v_provider text, v_dataset text, v_url text, v_access text) RETURNS int
    language plpgsql
as
$$
DECLARE _result int := (select scrape_id from staging.scrapes where provider_id = v_provider and dataset_id = v_dataset
                        and scraped_ts = TO_TIMESTAMP(v_access, 'YYYY-MM-DD hh24:MI:SS')
                        and uri = v_url);
BEGIN
    IF _result is null then
        INSERT INTO staging.scrapes (provider_id, dataset_id, uri, scraped_ts)
        values (v_provider, dataset_id, v_url, TO_TIMESTAMP(v_access, 'YYYY-MM-DD hh24:MI:SS'))
        returning scrape_id into _result;
    end if;
    return _result;
end;
$$;
create or replace procedure :myschema.save_attribute_data(v_region text, v_region_type text,  v_data jsonb)
    language plpgsql
as
$$
DECLARE
    _key      text;
    _value    text;
    _provider int;
    _scrape   int;
    _access   text := (v_data ->> 'access_time');
    _dataset int;
BEGIN

    _provider = staging.get_provider(v_data ->> 'provider');
    _dataset = staging.get_dataset(v_data ->> 'dataset');
    _scrape = staging.get_scrape(_provider, v_data->>'url', _access);

    perform staging.save_geounit(v_geounit, v_resolution);

    FOR _key, _value IN
        SELECT key, value FROM jsonb_each_text(v_data)
        LOOP
            --Insert into def table
            INSERT INTO staging.attributes(attr, details)
            values (_key, 'Automated Insert')
            ON CONFLICT DO NOTHING;

            --Insert into val table
            INSERT INTO staging.stav (scrape_id, geounit_id, vtime, attr, val, meta, parser)
            values (_scrape, v_region, _access, _key, COALESCE(_value, ''), '{}', null)
            ON CONFLICT DO NOTHING;
        END LOOP;
end
$$;

CREATE OR REPLACE FUNCTION :myschema.isnumeric(text) RETURNS BOOLEAN AS $$
DECLARE x NUMERIC;
BEGIN
    x = $1::NUMERIC;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$$
STRICT
LANGUAGE plpgsql IMMUTABLE;

-- CALL staging.save_attribute_data ('US^Montana^Beaverhead'::text, 'county'::text, '{"provider": "state", "country": "US", "state": "Montana", "region": null, "url": "https://services.arcgis.com/qnjIrwR8z5Izc0ij/ArcGIS/rest/services/COVID_Cases_Production_View/FeatureServer/0/query?f=json&where=Total%20%3C%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=NewCases%20desc%2CNAMELABEL%20asc&resultOffset=0&resultRecordCount=56&cacheHint=true", "access_time": "2020-04-21 13:24:22.212315", "county": "Beaverhead", "cases": 1.0, "updated": null, "deaths": 0.0, "presumptive": null, "recovered": 0.0, "tested": null, "hospitalized": 0.0, "negative": null, "counties": null, "severe": null, "lat": null, "lon": null, "fips": null, "monitored": null, "no_longer_monitored": null, "pending": null, "active": null, "inconclusive": null, "quarantined": null, "private_tests": null, "state_tests": null, "scrape_group": null, "resolution": "county", "icu": null, "cases_male": null, "cases_female": null, "lab": null, "lab_tests": null, "lab_positive": null, "lab_negative": null, "age_range": "0_9", "age_cases": 0.0, "age_percent": null, "age_deaths": null, "age_hospitalized": null, "age_tested": null, "age_negative": null, "age_hospitalized_percent": null, "age_negative_percent": null, "age_deaths_percent": null, "sex": null, "sex_counts": null, "sex_percent": null, "other": null, "other_value": null}'::jsonb);



--Functions

GRANT USAGE ON SCHEMA scraping TO reporters, jesters, cvadmin;
GRANT USAGE ON SCHEMA static TO reporters, jesters, cvadmin;
GRANT USAGE ON SCHEMA public TO reporters;
GRANT SELECT ON ALL TABLES IN SCHEMA public,scraping,static TO reporters;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public,scraping,static TO reporters;
GRANT USAGE ON SCHEMA :myschema TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA :myschema TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA :myschema TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA :myschema TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scraping TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA scraping, static TO jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA static TO jesters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA static TO ingester, cvadmin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scraping to ingester;

--Grant Default Priv to reporters for all tables in public.
alter default privileges in schema public grant all on tables to reporters;
alter default privileges in schema public grant all on sequences to reporters;

--cvadmin ability to backup
GRANT USAGE ON SCHEMA topology TO cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA topology TO cvadmin;
GRANT USAGE ON SCHEMA tiger TO cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA tiger TO cvadmin;
GRANT USAGE ON SCHEMA jesters TO cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA jesters TO cvadmin;

