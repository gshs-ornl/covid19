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
CREATE USER ingester WITH PASSWORD 'AngryMoose' IN ROLE jesters;
CREATE USER digester WITH PASSWORD 'LittlePumpkin' IN ROLE jesters;
CREATE USER librarian WITH PASSWORD 'HungryDeer' IN ROLE reporters;
CREATE USER historian WITH PASSWORD 'SmallGoose' IN ROLE reporters;
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
other_value numeric default null
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


--Functions

GRANT USAGE ON SCHEMA scraping TO reporters, jesters, cvadmin;
GRANT USAGE ON SCHEMA static TO reporters, jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA scraping,static TO reporters;
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

