SET TIME ZONE 'UTC';
CREATE ROLE jesters SUPERUSER LOGIN PASSWORD 'AngryMoose78':
CREATE ROLE reporters PASSWORD LOGIN "DogFoodIsGood";

CREATE USER cvadmin WITH CREATEDB CREATEUSER PASSWORD 'LovingLungfish';
CREATE USER ingester WITH PASSWORD 'AngryMoose' IN ROLE jesters;
CREATE USER digester WITH PASSWORD 'LittlePumpkin' IN ROLE jesters;
CREATE USER librarian WITH PASSWORD 'HungryDeer' IN ROLE reporters;
CREATE USER historian WITH PASSWORD 'SmallGoose' IN ROLE reporters;
CREATE USER guest WITH PASSWORD 'abc123';

CREATE DATABASE covidb WITH OWNER cvadmin;

GRANT CONNECT ON DATABASE covidb TO ingester, digester, librarian, historian
                                    guest;
CREATE SCHEMA IF NOT EXISTS scraping AUTHORIZATION jesters
  CREATE TABLE IF NOT EXISTS raw 
  (country varchar, state varchar, url varchar, raw_page text, 
   access_time timestamp, county varchar, cases integer,
   udpated timestamp with time zone, deaths integer, presumptive integer, 
   recovered integer, tested integer, hospitalized integer, negative integer,
   counties integer, severe integer, lat numeric, lon numeric, 
   parish varchar, monitored integer, no_longer_monitored integer, 
   pending_tests integer, active integer);

CREATE SCHEMA IF NOT EXISTS static AUTHORIAZATION jesters, reporters
  CREATE TABLE IF NOT EXISTS timezones
    (county_code varchar(2), country_name varchar, zone_name varchar,
     tz_abb, dst boolean, offset real)
  CREATE TABLE IF NOT EXISTS fips_lut
    (state varchar(2), county_name varchar, fips varchar(5), alt_name varchar)
  CREATE TABLE IF NOT EXISTS urls
    (state_abb varchar(2), state varchar, url varchar);
