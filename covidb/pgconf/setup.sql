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
CREATE USER cvadmin WITH CREATEDB CREATEROLE PASSWORD 'LovingLungfish';
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

CREATE TABLE IF NOT EXISTS static.urls
(
    id serial primary key ,
    state_id int REFERENCES static.states (id),
    state    varchar,
    url      varchar,
    CONSTRAINT cons_url UNIQUE (url)
);

CREATE SCHEMA IF NOT EXISTS scraping AUTHORIZATION jesters;

CREATE TABLE IF NOT EXISTS scraping.raw_data
(
provider varchar DEFAULT 'UNKNOWN' NOT NULL,
country varchar default null,
state varchar default null,
region varchar default null,
url varchar default null,
page text default null,
access_time timestamp not null,
county varchar default null,
cases integer default null,
updated timestamp with time zone default now(),
deaths integer default null,
presumptive integer default null,
recovered integer default null,
tested integer default null,
hospitalized integer default null,
negative integer default null,
counties integer default null,
severe integer default null,
lat numeric default null,
lon numeric default null,
fips varchar default null,
monitored integer default null,
no_longer_monitored integer default null,
pending integer default null,
active integer default null,
inconclusive integer default null,
quarantined integer default null,
scrape_group integer default null,
resolution varchar default null,
icu integer default null,
cases_male integer default null,
cases_female integer default null,
lab varchar default null,
lab_tests integer default null,
lab_positive integer default null,
lab_negative integer default null,
age_range varchar default null,
age_cases integer default null,
age_percent varchar default null,
age_deaths integer default null,
age_hospitalized integer default null,
age_tested integer default null,
age_negative integer default null,
age_hospitalized_percent varchar default null,
age_negative_percent varchar default null,
age_deaths_percent varchar default null,
sex varchar default null,
sex_counts integer default null,
sex_percent varchar default null,
sex_death integer default null,
other  varchar default null,
other_value varchar default null
);

CREATE TABLE IF NOT EXISTS scraping.age_ranges
(
    id         SERIAL PRIMARY KEY,
    age_ranges varchar,
    CONSTRAINT cons_url UNIQUE (age_ranges)
);

CREATE TABLE IF NOT EXISTS scraping.pages
(
    id          SERIAL PRIMARY KEY,
    page        text,
    url         varchar,
    hash        varchar(64),
    access_time timestamp with time zone
);
CREATE TABLE IF NOT EXISTS scraping.scrape_group
(
    id           SERIAL PRIMARY KEY,
    scrape_group integer NOT NULL
);

CREATE TABLE IF NOT EXISTS scraping.country_data
(
provider varchar DEFAULT 'UNKNOWN' NOT NULL,
country_id integer REFERENCES static.country (id),
region varchar default null,
url_id integer REFERENCES static.urls (id),
page_id integer references scraping.pages(id),
access_time timestamp not null,
cases integer default null,
updated date not null,
deaths integer default null,
presumptive integer default null,
recovered integer default null,
tested integer default null,
hospitalized integer default null,
negative integer default null,
counties integer default null,
severe integer default null,
lat numeric default null,
lon numeric default null,
monitored integer default null,
no_longer_monitored integer default null,
pending integer default null,
active integer default null,
inconclusive integer default null,
quarantined integer default null,
scrape_group_id integer REFERENCES scraping.scrape_group (id),
resolution varchar default null,
icu integer default null,
cases_male integer default null,
cases_female integer default null,
lab varchar default null,
lab_tests integer default null,
lab_positive integer default null,
lab_negative integer default null,
age_range integer REFERENCES scraping.age_ranges(id) default 1,
age_cases integer default null,
age_percent varchar default null,
age_deaths integer default null,
age_hospitalized integer default null,
age_tested integer default null,
age_negative integer default null,
age_hospitalized_percent varchar default null,
age_negative_percent varchar default null,
age_deaths_percent varchar default null,
sex varchar default null,
sex_counts integer default null,
sex_percent varchar default null,
sex_death integer default null,
other  varchar default null,
other_value integer default null,
CONSTRAINT const_country UNIQUE (country_id, provider, updated, sex, age_range)
);


CREATE TABLE IF NOT EXISTS scraping.state_data
(
provider varchar DEFAULT 'UNKNOWN' NOT NULL,
country_id integer REFERENCES static.country(id),
state_id integer REFERENCES static.states(id),
region varchar default null,
url_id integer references static.urls(id),
page_id integer references scraping.pages(id),
access_time timestamp not null,
cases integer default null,
updated date not null,
deaths integer default null,
presumptive integer default null,
recovered integer default null,
tested integer default null,
hospitalized integer default null,
negative integer default null,
counties integer default null,
severe integer default null,
lat numeric default null,
lon numeric default null,
monitored integer default null,
no_longer_monitored integer default null,
pending integer default null,
active integer default null,
inconclusive integer default null,
quarantined integer default null,
scrape_group_id integer references scraping.scrape_group(id),
resolution varchar default null,
icu integer default null,
cases_male integer default null,
cases_female integer default null,
lab varchar default null,
lab_tests integer default null,
lab_positive integer default null,
lab_negative integer default null,
age_range integer REFERENCES scraping.age_ranges(id) default 1,
age_cases integer default null,
age_percent varchar default null,
age_deaths integer default null,
age_hospitalized integer default null,
age_tested integer default null,
age_negative integer default null,
age_hospitalized_percent varchar default null,
age_negative_percent varchar default null,
age_deaths_percent varchar default null,
sex varchar default null,
sex_counts integer default null,
sex_percent varchar default null,
sex_death integer default null,
other  varchar default null,
other_value integer default null,
CONSTRAINT const_state UNIQUE (country_id,state_id,provider,updated, sex, age_range)
);

CREATE TABLE IF NOT EXISTS scraping.county_data
(
provider varchar DEFAULT 'UNKNOWN' NOT NULL,
country_id integer REFERENCES static.country(id),
state_id integer REFERENCES static.states(id),
county_id integer REFERENCES static.county(id),
region varchar default null,
url_id integer references static.urls(id),
page_id integer references scraping.pages(id),
access_time timestamp not null,
county varchar default null,
cases integer default null,
updated date not null,
deaths integer default null,
presumptive integer default null,
recovered integer default null,
tested integer default null,
hospitalized integer default null,
negative integer default null,
counties integer default null,
severe integer default null,
lat numeric default null,
lon numeric default null,
fips_id int references static.fips_lut(id),
monitored integer default null,
no_longer_monitored integer default null,
pending integer default null,
active integer default null,
inconclusive integer default null,
quarantined integer default null,
scrape_group_id integer references scraping.scrape_group(id),
resolution varchar default null,
icu integer default null,
cases_male integer default null,
cases_female integer default null,
lab varchar default null,
lab_tests integer default null,
lab_positive integer default null,
lab_negative integer default null,
age_range integer REFERENCES scraping.age_ranges(id) default 1,
age_cases integer default null,
age_percent varchar default null,
age_deaths integer default null,
age_hospitalized integer default null,
age_tested integer default null,
age_negative integer default null,
age_hospitalized_percent varchar default null,
age_negative_percent varchar default null,
age_deaths_percent varchar default null,
sex varchar default null,
sex_counts integer default null,
sex_percent varchar default null,
sex_death integer default null,
other  varchar default null,
other_value integer default null,
CONSTRAINT const_county UNIQUE (county_id,state_id, provider, updated, sex, age_range) --TODO: Add Age Bracket
);


--"Melt" Tables

CREATE TABLE IF NOT EXISTS scraping.attribute_classes
 (id SERIAL PRIMARY KEY,
  name varchar NOT NULL,
  units varchar,
  class varchar
);

CREATE TABLE IF NOT EXISTS scraping.attributes
 (id SERIAL PRIMARY KEY,
  attribute varchar NOT NULL
);

CREATE TABLE IF NOT EXISTS scraping.melt
 (country_id integer REFERENCES static.country(id),
  state_id integer REFERENCES static.country(id),
  county_id integer REFERENCES static.county(id),
  updated timestamp with time zone NOT NULL,
  page_id integer REFERENCES scraping.pages(id),
  scrape_group integer REFERENCES scraping.scrape_group(id),
  attribute_class integer REFERENCES scraping.attribute_classes(id),
  attribute integer REFERENCES scraping.attributes(id),
  value numeric NOT NULL
);

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE if not exists staging.provider (
      provider_id TEXT PRIMARY KEY
    , name TEXT
    , insert_ts TIMESTAMP WITH TIME ZONE DEFAULT now()
);


CREATE TABLE if not exists staging.scrapes (
      scrape_id SERIAL UNIQUE
    , provider_id TEXT REFERENCES staging.provider(provider_id)
    , uri TEXT
    , scraped_ts TIMESTAMP WITH TIME ZONE
    , doc TEXT
    , csv_file TEXT -- source CSV file
    , csv_row INT -- row in the CSV file
    , PRIMARY KEY (provider_id, uri, scraped_ts)
);

CREATE TABLE if not exists staging.attr_def (
      attr TEXT NOT NULL PRIMARY KEY
    , details TEXT
);

create table if not exists staging.regions
(
      region_id TEXT PRIMARY KEY
    , resolution TEXT -- country, state, county, etc.
    , admin_lvl INT GENERATED ALWAYS AS (CHAR_LENGTH(region_id) - CHAR_LENGTH(REPLACE(region_id, '^', ''))) STORED
    , details JSONB
);

CREATE TABLE if not exists staging.attr_val (
      scrape_id INT REFERENCES staging.scrapes(scrape_id) ON DELETE CASCADE
    , region_id TEXT REFERENCES staging.regions(region_id)
    , valid_time TEXT -- should be of type 'time with precision'
    , attr TEXT REFERENCES staging.attr_def(attr)
    , val TEXT NOT NULL
    , ext JSONB
    , parser TEXT
    , PRIMARY KEY (scrape_id, region_id, valid_time, attr)
);

create or replace function staging.get_provider(v_provider text) RETURNS int
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

create or replace function staging.get_scrape(v_provider text, v_url text, v_access text) RETURNS int
    language plpgsql
as
$$
DECLARE _result int := (select scrape_id from staging.scrapes where provider_id = v_provider
                        and scraped_ts = TO_TIMESTAMP(v_access, 'YYYY-MM-DD hh24:MI:SS')
                        and uri = v_url);
BEGIN
    IF _result is null then
        INSERT INTO staging.scrapes (provider_id, uri, scraped_ts)
        values (v_provider, v_url, TO_TIMESTAMP(v_access, 'YYYY-MM-DD hh24:MI:SS'))
        returning scrape_id into _result;
    end if;
    return _result;
end;
$$;

create or replace function staging.save_region(v_region text, v_region_type text) returns void
    language plpgsql
as
$$

BEGIN
    INSERT INTO staging.regions (region_id, resolution)
    values (v_region, v_region_type)
    ON CONFLICT DO NOTHING;
end;
$$;

create or replace procedure staging.save_attribute_data(v_region text, v_region_type text,  v_data jsonb)
    language plpgsql
as
$$
DECLARE
    _key      text;
    _value    text;
    _provider int;
    _scrape   int;
    _access   text := (v_data ->> 'access_time');
BEGIN

    _provider = staging.get_provider(v_data ->> 'provider');
    _scrape = staging.get_scrape(_provider, v_data->>'url', _access);

    perform staging.save_region(v_region, v_region_type);

    FOR _key, _value IN
        SELECT key, value FROM jsonb_each_text(v_data)
        LOOP
            --Insert into def table
            INSERT INTO staging.attr_def (attr, details)
            values (_key, 'Automated Insert')
            ON CONFLICT DO NOTHING;

            --Insert into val table
            INSERT INTO staging.attr_val (scrape_id, region_id, valid_time, attr, val, ext, parser)
            values (_scrape, v_region, _access, _key, COALESCE(_value, ''), '{}', null)
            ON CONFLICT DO NOTHING;
        END LOOP;
end
$$;

CREATE OR REPLACE FUNCTION staging.isnumeric(text) RETURNS BOOLEAN AS $$
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

/*
select pid, query, query_start from pg_stat_activity where datname = 'staging' and pid != pg_backend_pid()
and query != 'SHOW TRANSACTION ISOLATION LEVEL'
order by query_start desc;

select * from staging.regions where region_id like '%Florida%'

select * from staging.attr_val v
join staging.regions r ON r.region_id = v.region_id
where v.val != 'None';
*/



-- CALL staging.save_attribute_data ('US^Montana^Beaverhead'::text, 'county'::text, '{"provider": "state", "country": "US", "state": "Montana", "region": null, "url": "https://services.arcgis.com/qnjIrwR8z5Izc0ij/ArcGIS/rest/services/COVID_Cases_Production_View/FeatureServer/0/query?f=json&where=Total%20%3C%3E%200&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&orderByFields=NewCases%20desc%2CNAMELABEL%20asc&resultOffset=0&resultRecordCount=56&cacheHint=true", "access_time": "2020-04-21 13:24:22.212315", "county": "Beaverhead", "cases": 1.0, "updated": null, "deaths": 0.0, "presumptive": null, "recovered": 0.0, "tested": null, "hospitalized": 0.0, "negative": null, "counties": null, "severe": null, "lat": null, "lon": null, "fips": null, "monitored": null, "no_longer_monitored": null, "pending": null, "active": null, "inconclusive": null, "quarantined": null, "private_tests": null, "state_tests": null, "scrape_group": null, "resolution": "county", "icu": null, "cases_male": null, "cases_female": null, "lab": null, "lab_tests": null, "lab_positive": null, "lab_negative": null, "age_range": "0_9", "age_cases": 0.0, "age_percent": null, "age_deaths": null, "age_hospitalized": null, "age_tested": null, "age_negative": null, "age_hospitalized_percent": null, "age_negative_percent": null, "age_deaths_percent": null, "sex": null, "sex_counts": null, "sex_percent": null, "other": null, "other_value": null}'::jsonb);



--Functions

GRANT USAGE ON SCHEMA scraping TO reporters, jesters, cvadmin;
GRANT USAGE ON SCHEMA static TO reporters, jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA scraping,static TO reporters;
GRANT USAGE ON SCHEMA staging TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA staging TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA staging TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA staging TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scraping TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA scraping, static TO jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA static TO jesters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA static TO ingester, cvadmin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scraping to ingester;

--cvadmin ability to backup
GRANT USAGE ON SCHEMA topology TO cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA topology TO cvadmin;
GRANT USAGE ON SCHEMA tiger TO cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA tiger TO cvadmin;
GRANT USAGE ON SCHEMA jesters TO cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA jesters TO cvadmin;

