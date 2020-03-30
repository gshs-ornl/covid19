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
SELECT 'CREATE DATABASE covidb WITH OWNER cvadmin'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'covidb')\gexec

GRANT CONNECT ON DATABASE covidb TO ingester, digester, librarian, historian,
                                    guest;
\c covidb
CREATE EXTENSION pgcrypto;
CREATE SCHEMA IF NOT EXISTS static AUTHORIZATION jesters;
CREATE TABLE IF NOT EXISTS static.timezones
 (county_code varchar(2),
  country_name varchar,
  zone_name varchar,
  tz_abb text,
  dst boolean,
  _offset real);
CREATE TABLE IF NOT EXISTS static.fips_lut
 (state varchar(2),
  county_name varchar,
  fips varchar(5),
  alt_name varchar);
CREATE TABLE IF NOT EXISTS static.country
 (id SERIAL PRIMARY KEY,
  iso2c varchar(2),
  iso3c varchar(3),
  country varchar,
CONSTRAINT const_country UNIQUE (country));
CREATE TABLE IF NOT EXISTS static.states
 (id SERIAL PRIMARY KEY,
  country_id int REFERENCES static.country(id),
  fips varchar(2),
  abb varchar(2),
  state varchar,
CONSTRAINT const_states UNIQUE(state));
CREATE TABLE IF NOT EXISTS static.urls
 (state_id int REFERENCES static.states(id),
  state varchar,
  url varchar,
CONSTRAINT cons_url UNIQUE(url));
CREATE TABLE IF NOT EXISTS static.county
 (id SERIAL PRIMARY KEY,
  county_name varchar,
  state_id integer REFERENCES static.states(id),
  fips varchar(5),
  alt_name varchar DEFAULT NULL,
  non_std varchar DEFAULT NULL);

CREATE SCHEMA IF NOT EXISTS scraping AUTHORIZATION jesters;
CREATE TABLE IF NOT EXISTS scraping.raw_data
(country varchar,
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
private_test integer DEFAULT NULL,
state_test integer DEFAULT NULL,
no_longer_monitored integer DEFAULT NULL,
pending_tests integer DEFAULT NULL,
active integer DEFAULT NULL,
inconclusive integer DEFAULT NULL,
scrape_group integer NOT NULL,
icu integer DEFAULT NULL,
lab varchar DEFAULT NULL,
lab_tests integer DEFAULT NULL,
lab_positive integer DEFAULT NULL,
lab_negative integer DEFAULT NULL,
age_range varchar DEFAULT NULL,
age_cases integer DEFAULT NULL,
age_percent varchar DEFAULT NULL,
age_hospitalized integer DEFAULT NULL,
age_hospitalized_percent varchar DEFAULT NULL,
age_deaths integer DEFAULT NULL,
age_deaths_percent varchar DEFAULT NULL,
other varchar DEFAULT NULL,
other_value integer DEFAULT NULL,
data_source varchar DEFAULT NULL
);
CREATE TABLE IF NOT EXISTS scraping.age_ranges
(id SERIAL PRIMARY KEY,
age_ranges varchar);
CREATE TABLE IF NOT EXISTS scraping.pages
(id SERIAL PRIMARY KEY,
page text,
url varchar,
hash varchar(64),
access_time timestamp with time zone);
CREATE TABLE IF NOT EXISTS scraping.scrape_group
(id SERIAL PRIMARY KEY,
scrape_group integer NOT NULL);
CREATE TABLE IF NOT EXISTS scraping.pages
(id SERIAL PRIMARY KEY,
url varchar NOT NULL,
page text NOT NULL,
updated timestamp with time zone);
CREATE TABLE IF NOT EXISTS scraping.country_data
(
country_id integer REFERENCES static.country(id),
access_time timestamp,
updated timestamp with time zone,
cases integer DEFAULT NULL,
deaths integer DEFAULT NULL,
presumptive integer DEFAULT NULL,
tested integer DEFAULT NULL,
hospitalized integer DEFAULT NULL,
negative integer DEFAULT NULL,
monitored integer DEFAULT NULL,
no_longer_monitored integer DEFAULT NULL,
inconclusive integer DEFAULT NULL,
pending_tests integer DEFAULT NULL,
active integer DEFAULT NULL,
scrape_group  integer REFERENCES scraping.scrape_group(id),
page_id integer REFERENCES scraping.pages(id),
icu integer DEFAULT NULL,
lab varchar DEFAULT NULL,
lab_tests integer DEFAULT NULL,
lab_positive integer DEFAULT NULL,
lab_negative integer DEFAULT NULL,
age_range varchar DEFAULT NULL,
age_cases integer DEFAULT NULL,
age_percent varchar DEFAULT NULL,
age_hospitalized integer DEFAULT NULL,
age_hospitalized_percent varchar DEFAULT NULL,
age_deaths integer DEFAULT NULL,
age_deaths_percent varchar DEFAULT NULL,
other varchar DEFAULT NULL,
other_value integer DEFAULT NULL,
data_source varchar DEFAULT NULL,
CONSTRAINT const_country_page_id UNIQUE (country_id, page_id)
);
CREATE TABLE IF NOT EXISTS scraping.state_data
(
country_id integer REFERENCES static.country(id),
state_id integer REFERENCES static.states(id),
access_time timestamp,
updated timestamp with time zone,
cases integer DEFAULT NULL,
deaths integer DEFAULT NULL,
presumptive integer DEFAULT NULL,
tested integer DEFAULT NULL,
hospitalized integer DEFAULT NULL,
negative integer DEFAULT NULL,
monitored integer DEFAULT NULL,
no_longer_monitored integer DEFAULT NULL,
inconclusive integer DEFAULT NULL,
pending_tests integer DEFAULT NULL,
active integer DEFAULT NULL,
scrape_group  integer REFERENCES scraping.scrape_group(id),
page_id integer REFERENCES scraping.pages(id),
icu integer DEFAULT NULL,
lab varchar DEFAULT NULL,
lab_tests integer DEFAULT NULL,
lab_positive integer DEFAULT NULL,
lab_negative integer DEFAULT NULL,
age_range varchar DEFAULT NULL,
age_cases integer DEFAULT NULL,
age_percent varchar DEFAULT NULL,
age_hospitalized integer DEFAULT NULL,
age_hospitalized_percent varchar DEFAULT NULL,
age_deaths integer DEFAULT NULL,
age_deaths_percent varchar DEFAULT NULL,
other varchar DEFAULT NULL,
other_value integer DEFAULT NULL,
data_source varchar DEFAULT NULL,
CONSTRAINT const_state_page_id UNIQUE (state_id, page_id)
);
CREATE TABLE IF NOT EXISTS scraping.county_data
(
    country_id integer REFERENCES static.country(id),
state_id integer REFERENCES static.states(id),
county_id integer REFERENCES static.county(id),
access_time timestamp,
updated timestamp with time zone,
cases integer DEFAULT NULL,
deaths integer DEFAULT NULL,
presumptive integer DEFAULT NULL,
tested integer DEFAULT NULL,
hospitalized integer DEFAULT NULL,
negative integer DEFAULT NULL,
monitored integer DEFAULT NULL,
no_longer_monitored integer DEFAULT NULL,
inconclusive integer DEFAULT NULL,
pending_tests integer DEFAULT NULL,
active integer DEFAULT NULL,
scrape_group integer REFERENCES scraping.scrape_group(id),
page_id integer REFERENCES scraping.pages(id),
icu integer DEFAULT NULL,
lab varchar DEFAULT NULL,
lab_tests integer DEFAULT NULL,
lab_positive integer DEFAULT NULL,
lab_negative integer DEFAULT NULL,
age_range varchar DEFAULT NULL,
age_cases integer DEFAULT NULL,
age_percent varchar DEFAULT NULL,
age_hospitalized integer DEFAULT NULL,
age_hospitalized_percent varchar DEFAULT NULL,
age_deaths integer DEFAULT NULL,
age_deaths_percent varchar DEFAULT NULL,
other varchar DEFAULT NULL,
other_value integer DEFAULT NULL,
data_source varchar DEFAULT NULL,
CONSTRAINT const_county_page_id UNIQUE (county_id, page_id)
);

create or replace function scraping.fn_update_scraping() returns trigger
    language plpgsql
as
$$
DECLARE
    v_page_id      int := (select id
                           from scraping.pages
                           where hash = digest(quote_literal(NEW.raw_page), 'sha256')::varchar(64));
    v_scrape_group int := (select id
                           from scraping.scrape_group
                           where scrape_group = NEW.scrape_group);
    v_age_range int := (select id
                           from scraping.age_ranges
                           where age_ranges.age_ranges = NEW.age_range);

BEGIN

    IF (v_page_id is null) THEN
        INSERT INTO scraping.pages(page, url, hash, access_time)
        select NEW.raw_page, NEW.url, digest(quote_literal(NEW.raw_page), 'sha256')::varchar(64), NEW.access_time
        returning id into v_page_id;

    END IF;

    IF (v_scrape_group is null) THEN
        INSERT INTO scraping.scrape_group(scrape_group)
        select NEW.scrape_group
        returning id into v_scrape_group;

    END IF;

    IF (v_age_range is null) THEN
        INSERT INTO scraping.age_ranges(age_ranges)
        select NEW.age_range returning id into v_age_range;
    end if;


    IF (NEW.county is null) THEN --State Level data

        INSERT INTO scraping.state_data(country_id, state_id, access_time, updated, cases, deaths, presumptive, tested,
                                        hospitalized, negative, monitored, no_longer_monitored, inconclusive,
                                        pending_tests,
                                        active,
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
                                        age_deaths_percent, other, other_value, scrape_group, page_id)
        values ((select id from static.country c where lower(NEW.country) = lower(c.country)),
                (select id from static.states s where lower(NEW.state) = lower(s.state)),
                NEW.access_time,
                NEW.updated, NEW.cases, NEW.deaths, NEW.presumptive, NEW.tested,
                NEW.hospitalized, NEW.negative, NEW.monitored, NEW.no_longer_monitored, NEW.inconclusive,
                NEW.pending_tests,
                NEW.active,
                NEW.icu,
                NEW.lab,
                NEW.lab_tests,
                NEW.lab_positive,
                NEW.lab_negative,
                NEW.age_range,
                NEW.age_cases,
                NEW.age_percent,
                NEW.age_hospitalized,
                NEW.age_hospitalized_percent,
                NEW.age_deaths,
                NEW.age_deaths_percent,
                NEW.other,
                NEW.other_value,
                NEW.data_source,
                v_scrape_group, v_page_id)
        ON CONFLICT ON CONSTRAINT const_state_page_id
            DO UPDATE
            SET access_time              = NEW.access_time,
                updated                  = NEW.updated,
                cases                    = NEW.cases,
                deaths                   = NEW.deaths,
                presumptive              = NEW.presumptive,
                tested                   = NEW.tested,
                hospitalized             = NEW.hospitalized,
                negative                 = NEW.negative,
                monitored                = NEW.monitored,
                no_longer_monitored      = NEW.no_longer_monitored,
                inconclusive=NEW.inconclusive,
                pending_tests            = NEW.pending_tests,
                active                   = NEW.active,
                icu                      = NEW.icu,
                lab                      = NEW.lab,
                lab_tests                = NEW.lab_tests,
                lab_positive             = NEW.lab_positive,
                lab_negative             = NEW.lab_negative,
                age_range                = NEW.age_range,
                age_cases                = NEW.age_cases,
                age_percent              = NEW.age_percent,
                age_hospitalized         = NEW.age_hospitalized,
                age_hospitalized_percent = NEW.age_hospitalized_percent,
                age_deaths               = NEW.age_deaths,
                age_deaths_percent       = NEW.age_deaths_percent,
                data_source = NEW.data_source,
                other = NEW.other,
                other_value = NEW.other_value,
                scrape_group             = v_scrape_group;
    end if;

    IF (NEW.county is null and NEW.state is null) THEN --Country Level data

        INSERT INTO scraping.country_data(country_id, access_time, updated, cases, deaths, presumptive, tested,
                                        hospitalized, negative, monitored, no_longer_monitored, inconclusive,
                                        pending_tests,
                                        active,
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
                                        age_deaths_percent, other, other_value, data_source,scrape_group, page_id)
        values ((select id from static.country c where lower(NEW.country) = lower(c.country)),
                NEW.access_time,
                NEW.updated, NEW.cases, NEW.deaths, NEW.presumptive, NEW.tested,
                NEW.hospitalized, NEW.negative, NEW.monitored, NEW.no_longer_monitored, NEW.inconclusive,
                NEW.pending_tests,
                NEW.active,
                NEW.icu,
                NEW.lab,
                NEW.lab_tests,
                NEW.lab_positive,
                NEW.lab_negative,
                NEW.age_range,
                NEW.age_cases,
                NEW.age_percent,
                NEW.age_hospitalized,
                NEW.age_hospitalized_percent,
                NEW.age_deaths,
                NEW.age_deaths_percent,
                NEW.other,
                NEW.other_value,
                NEW.data_source,
                v_scrape_group, v_page_id)
        ON CONFLICT ON CONSTRAINT const_state_page_id
            DO UPDATE
            SET access_time              = NEW.access_time,
                updated                  = NEW.updated,
                cases                    = NEW.cases,
                deaths                   = NEW.deaths,
                presumptive              = NEW.presumptive,
                tested                   = NEW.tested,
                hospitalized             = NEW.hospitalized,
                negative                 = NEW.negative,
                monitored                = NEW.monitored,
                no_longer_monitored      = NEW.no_longer_monitored,
                inconclusive=NEW.inconclusive,
                pending_tests            = NEW.pending_tests,
                active                   = NEW.active,
                icu                      = NEW.icu,
                lab                      = NEW.lab,
                lab_tests                = NEW.lab_tests,
                lab_positive             = NEW.lab_positive,
                lab_negative             = NEW.lab_negative,
                age_range                = NEW.age_range,
                age_cases                = NEW.age_cases,
                age_percent              = NEW.age_percent,
                age_hospitalized         = NEW.age_hospitalized,
                age_hospitalized_percent = NEW.age_hospitalized_percent,
                age_deaths               = NEW.age_deaths,
                age_deaths_percent       = NEW.age_deaths_percent,
                other = NEW.other,
                other_value = NEW.other_value,
                data_source = NEW.data_source,
                scrape_group             = v_scrape_group;
    end if;

    IF (NEW.state is not null AND NEW.county is not null) THEN --Typical County Data

            INSERT INTO scraping.county_data(
                                             country_id,
                                             state_id,
                                             county_id,access_time,
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
               active,
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
                data_source,
               other,
               other_value, scrape_group, page_id)
        values ((select id from static.country c where lower(NEW.country) = lower(c.country)),
                (select id from static.states s where lower(NEW.state) = lower(s.state)),
                (select id
                 from static.county cty
                 where lower(NEW.county) = lower(cty.county_name)
                   and cty.state_id = (select id from static.states s where lower(NEW.state) = lower(s.state))),
                NEW.access_time,
                NEW.updated, NEW.cases, NEW.deaths, NEW.presumptive, NEW.tested,
                NEW.hospitalized, NEW.negative, NEW.monitored, NEW.no_longer_monitored, NEW.inconclusive,
                NEW.pending_tests,
                NEW.active,
                NEW.icu,
                NEW.lab,
                NEW.lab_tests,
                NEW.lab_positive,
                NEW.lab_negative,
                NEW.age_range,
                NEW.age_cases,
                NEW.age_percent,
                NEW.age_hospitalized,
                NEW.age_hospitalized_percent,
                NEW.age_deaths,
                NEW.age_deaths_percent,
                                NEW.other,
                NEW.other_value,
                NEW.data_source,
                v_scrape_group, v_page_id)
        ON CONFLICT ON CONSTRAINT const_county_page_id
            DO UPDATE
            SET access_time              = NEW.access_time,
                updated                  = NEW.updated,
                cases                    = NEW.cases,
                deaths                   = NEW.deaths,
                presumptive              = NEW.presumptive,
                tested                   = NEW.tested,
                hospitalized             = NEW.hospitalized,
                negative                 = NEW.negative,
                monitored                = NEW.monitored,
                no_longer_monitored      = NEW.no_longer_monitored,
                inconclusive=NEW.inconclusive,
                pending_tests            = NEW.pending_tests,
                active                   = NEW.active,
                icu                      = NEW.icu,
                lab                      = NEW.lab,
                lab_tests                = NEW.lab_tests,
                lab_positive             = NEW.lab_positive,
                lab_negative             = NEW.lab_negative,
                age_range                = NEW.age_range,
                age_cases                = NEW.age_cases,
                age_percent              = NEW.age_percent,
                age_hospitalized         = NEW.age_hospitalized,
                age_hospitalized_percent = NEW.age_hospitalized_percent,
                age_deaths               = NEW.age_deaths,
                age_deaths_percent       = NEW.age_deaths_percent,
                data_source = NEW.data_source,
                other = NEW.other,
                other_value = NEW.other_value,
                scrape_group             = v_scrape_group;
    end if;

    RETURN NEW;
END
$$;


DROP TRIGGER IF EXISTS tr_raw_data on scraping.raw_data;
CREATE TRIGGER  tr_raw_data
    AFTER INSERT
    ON scraping.raw_data
    FOR EACH ROW
EXECUTE PROCEDURE scraping.fn_update_scraping();


GRANT USAGE ON SCHEMA scraping TO reporters, jesters, cvadmin;
GRANT USAGE ON SCHEMA static TO reporters, jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA scraping,static TO reporters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scraping TO jesters, cvadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA scraping TO jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA static TO jesters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA static TO ingester, cvadmin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scraping to ingester;
/**************** Country Data *********************/
DO
$$
    BEGIN
        if (select count(*) from static.country) = 0 then
            CREATE temporary TABLE iso_lookup
            (
                cc_id            integer,
                cc_name          varchar(254),
                iso_short_name   text,
                iso_alpha2_code  text,
                iso_alpha3_code  text,
                iso_numeric_code text,
                iso_independent  boolean,
                inferred_match   boolean
            );


            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (3, 'Akrotiri (UK)', 'United Kingdom of Great Britain and Northern Ireland', 'GB', 'GBR', '826',
                    true, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (16, 'Ashmore & Cartier Is (Aus)', 'Australia', 'AU', 'AUS', '36', true, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (1, 'Abyei (disp)', 'Abyei (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (4, 'Aksai Chin (disp)', 'Aksai Chin (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (210, 'Sanafir & Tiran Is. (disp)', 'Sanafir & Tiran Is. (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (214, 'Senkakus (disp)', 'Senkakus (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (135, 'Siachen-Saltoro (disp)', 'Siachen-Saltoro (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (225, 'Spratly Is (disp)', 'Spratly Is (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (7, 'American Samoa (US)', 'American Samoa', 'AS', 'ASM', '16', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (30, 'Bouvet Island (Nor)', 'Bouvet Island', 'BV', 'BVT', '74', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (42, 'British Indian Oc Terr (UK)', 'British Indian Ocean Territory', 'IO', 'IOT', '86', false,
                    false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (56, 'Cayman Is (UK)', 'Cayman Islands', 'KY', 'CYM', '136', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (57, 'Central African Rep', 'Central African Republic', 'CF', 'CAF', '140', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (37, 'Christmas I (Aus)', 'Christmas Island', 'CX', 'CXR', '162', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (32, 'Cocos (Keeling) Is (Aus)', 'Cocos (Keeling) Islands', 'CC', 'CCK', '166', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (39, 'Congo, Dem Rep of the', 'Congo, Democratic Republic of the', 'CD', 'COD', '180', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (80, 'Falkland Islands (UK) (disp)', 'Falkland Islands (Malvinas)', 'FK', 'FLK', '238', false,
                    false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (86, 'French Guiana (Fr)', 'French Guiana', 'GF', 'GUF', '254', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (87, 'French Polynesia (Fr)', 'French Polynesia', 'PF', 'PYF', '258', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (98, 'Gibraltar (UK)', 'Gibraltar', 'GI', 'GIB', '292', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (100, 'Greenland (Den)', 'Greenland', 'GL', 'GRL', '304', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (13, 'Anguilla (UK)', 'Anguilla', 'AI', 'AIA', '660', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (174, 'Netherlands [Caribbean]', 'Bonaire, Sint Eustatius and Saba', 'BQ', 'BES', '535', false,
                    true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (58, 'CH-IN (disp)', 'CH-IN (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (179, 'No Man''s Land (disp)', 'No Man''s Land (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (175, 'New Caledonia (Fr)', 'New Caledonia', 'NC', 'NCL', '540', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (102, 'Guadeloupe (Fr)', 'Guadeloupe', 'GP', 'GLP', '312', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (119, 'Hong Kong (Ch)', 'Hong Kong', 'HK', 'HKG', '344', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (138, 'Isle of Man (UK)', 'Isle of Man', 'IM', 'IMN', '833', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (166, 'Marshall Is', 'Marshall Islands', 'MH', 'MHL', '584', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (167, 'Martinique (Fr)', 'Martinique', 'MQ', 'MTQ', '474', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (172, 'Micronesia, Fed States of', 'Micronesia (Federated States of)', 'FM', 'FSM', '583', true,
                    false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (90, 'Montserrat (UK)', 'Montserrat', 'MS', 'MSR', '500', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (9, 'Antigua & Barbuda', 'Antigua and Barbuda', 'AG', 'ATG', '28', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (20, 'Bahamas, The', 'Bahamas', 'BS', 'BHS', '44', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (25, 'Bermuda (UK)', 'Bermuda', 'BM', 'BMU', '60', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (27, 'Bolivia', 'Bolivia (Plurinational State of)', 'BO', 'BOL', '68', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (28, 'Bosnia & Herzegovina', 'Bosnia and Herzegovina', 'BA', 'BIH', '70', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (43, 'Brunei', 'Brunei Darussalam', 'BN', 'BRN', '96', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (41, 'Cook Is (NZ)', 'Cook Islands', 'CK', 'COK', '184', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (81, 'Faroe Is (Den)', 'Faroe Islands', 'FO', 'FRO', '234', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (180, 'Norfolk I (Aus)', 'Norfolk Island', 'NF', 'NFK', '574', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (181, 'Northern Mariana Is (US)', 'Northern Mariana Islands', 'MP', 'MNP', '580', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (197, 'Puerto Rico (US)', 'Puerto Rico', 'PR', 'PRI', '630', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (211, 'Sao Tome & Principe', 'Sao Tome and Principe', 'ST', 'STP', '678', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (215, 'Sint Maarten (Neth)', 'Sint Maarten (Dutch part)', 'SX', 'SXM', '534', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (218, 'Solomon Is', 'Solomon Islands', 'SB', 'SLB', '90', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (237, 'Svalbard (Nor)', 'Svalbard and Jan Mayen', 'SJ', 'SJM', '744', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (207, 'Trinidad & Tobago', 'Trinidad and Tobago', 'TT', 'TTO', '780', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (258, 'Venezuela', 'Venezuela (Bolivarian Republic of)', 'VE', 'VEN', '862', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (94, 'Gaza Strip (disp)', 'Palestine, State of', 'PS', 'PSE', '275', false, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (84, 'Fr S & Antarctic Lands (Fr)', 'French Southern Territories', 'TF', 'ATF', '260', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (223, 'Spain [Canary Is]', 'Spain', 'ES', 'ESP', '724', false, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (224, 'Spain [Plazas de Soberania]', 'Spain', 'ES', 'ESP', '724', false, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (67, 'Dhekelia (UK)', 'United Kingdom of Great Britain and Northern Ireland', 'GB', 'GBR', '826',
                    true, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (51, 'Coral Sea Is (Aus)', 'Australia', 'AU', 'AUS', '36', true, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (38, 'Clipperton I (Fr)', 'France', 'FR', 'FRA', '250', null, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (141, 'Jan Mayen (Nor)', 'Norway', 'NO', 'NOR', '578', null, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (195, 'Portugal [Azores]', 'Portugal', 'PT', 'PRT', '620', null, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (196, 'Portugal [Madeira Is]', 'Portugal', 'PT', 'PRT', '620', null, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (159, 'Macedonia', 'North Macedonia', 'MK', 'MKD', '807', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (89, 'Gambia, The', 'Gambia', 'GM', 'GMB', '270', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (109, 'Guernsey (UK)', 'Guernsey', 'GG', 'GGY', '831', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (117, 'Heard I & McDonald Is (Aus)', 'Heard Island and McDonald Islands', 'HM', 'HMD', '334', false,
                    false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (114, 'Jersey (UK)', 'Jersey', 'JE', 'JEY', '832', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (170, 'Mayotte (Fr)', 'Mayotte', 'YT', 'MYT', '175', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (173, 'Moldova', 'Moldova, Republic of', 'MD', 'MDA', '498', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (50, 'Canada', 'Canada', 'CA', 'CAN', '124', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (59, 'Chad', 'Chad', 'TD', 'TCD', '148', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (60, 'Chile', 'Chile', 'CL', 'CHL', '152', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (61, 'China', 'China', 'CN', 'CHN', '156', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (33, 'Colombia', 'Colombia', 'CO', 'COL', '170', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (34, 'Comoros', 'Comoros', 'KM', 'COM', '174', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (52, 'Costa Rica', 'Costa Rica', 'CR', 'CRI', '188', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (54, 'Croatia', 'Croatia', 'HR', 'HRV', '191', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (55, 'Cuba', 'Cuba', 'CU', 'CUB', '192', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (63, 'Cyprus', 'Cyprus', 'CY', 'CYP', '196', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (64, 'Czechia', 'Czechia', 'CZ', 'CZE', '203', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (66, 'Denmark', 'Denmark', 'DK', 'DNK', '208', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (68, 'Djibouti', 'Djibouti', 'DJ', 'DJI', '262', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (69, 'Dominica', 'Dominica', 'DM', 'DMA', '212', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (70, 'Dominican Republic', 'Dominican Republic', 'DO', 'DOM', '214', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (73, 'Ecuador', 'Ecuador', 'EC', 'ECU', '218', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (74, 'Egypt', 'Egypt', 'EG', 'EGY', '818', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (75, 'El Salvador', 'El Salvador', 'SV', 'SLV', '222', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (76, 'Equatorial Guinea', 'Equatorial Guinea', 'GQ', 'GNQ', '226', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (110, 'Guinea', 'Guinea', 'GN', 'GIN', '324', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (111, 'Guinea-Bissau', 'Guinea-Bissau', 'GW', 'GNB', '624', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (112, 'Guyana', 'Guyana', 'GY', 'GUY', '328', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (113, 'Haiti', 'Haiti', 'HT', 'HTI', '332', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (118, 'Honduras', 'Honduras', 'HN', 'HND', '340', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (130, 'Korea, North', 'Korea (Democratic People''s Republic of)', 'KP', 'PRK', '408', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (131, 'Korea, South', 'Korea, Republic of', 'KR', 'KOR', '410', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (15, 'Aruba (Neth)', 'Aruba', 'AW', 'ABW', '533', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (275, 'Burma', 'Myanmar', 'MM', 'MMR', '104', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (40, 'Congo, Rep of the', 'Congo', 'CG', 'COG', '178', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (53, 'Cote d''Ivoire', 'Côte d''Ivoire', 'CI', 'CIV', '384', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (62, 'Curacao (Neth)', 'Curaçao', 'CW', 'CUW', '531', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (123, 'Iran', 'Iran (Islamic Republic of)', 'IR', 'IRN', '364', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (145, 'Laos', 'Lao People''s Democratic Republic', 'LA', 'LAO', '418', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (31, 'Br Virgin Is (UK)', 'Virgin Islands (British)', 'VG', 'VGB', '92', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (35, 'Br Virgin Islands (UK)', 'Virgin Islands (British)', 'VG', 'VGB', '92', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (104, 'Guam (US)', 'Guam', 'GU', 'GUM', '316', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (158, 'Macau (Ch)', 'Macao', 'MO', 'MAC', '446', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (250, 'United Kingdom', 'United Kingdom of Great Britain and Northern Ireland', 'GB', 'GBR', '826',
                    true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (263, 'Western Sahara (disp)', 'Western Sahara', 'EH', 'ESH', '732', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (251, 'United States', 'United States of America', 'US', 'USA', '840', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (192, 'Pitcairn Is (UK)', 'Pitcairn', 'PN', 'PCN', '612', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (200, 'Russia', 'Russian Federation', 'RU', 'RUS', '643', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (242, 'Taiwan', 'Taiwan, Province of China[a]', 'TW', 'TWN', '158', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (244, 'Tanzania', 'Tanzania, United Republic of', 'TZ', 'TZA', '834', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (205, 'Tokelau (NZ)', 'Tokelau', 'TK', 'TKL', '772', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (229, 'Turks & Caicos Is (UK)', 'Turks and Caicos Islands', 'TC', 'TCA', '796', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (261, 'Wallis & Futuna (Fr)', 'Wallis and Futuna', 'WF', 'WLF', '876', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (2, 'Afghanistan', 'Afghanistan', 'AF', 'AFG', '4', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (5, 'Albania', 'Albania', 'AL', 'ALB', '8', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (6, 'Algeria', 'Algeria', 'DZ', 'DZA', '12', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (11, 'Andorra', 'Andorra', 'AD', 'AND', '20', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (12, 'Angola', 'Angola', 'AO', 'AGO', '24', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (8, 'Antarctica', 'Antarctica', 'AQ', 'ATA', '10', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (10, 'Argentina', 'Argentina', 'AR', 'ARG', '32', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (14, 'Armenia', 'Armenia', 'AM', 'ARM', '51', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (17, 'Australia', 'Australia', 'AU', 'AUS', '36', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (18, 'Austria', 'Austria', 'AT', 'AUT', '40', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (19, 'Azerbaijan', 'Azerbaijan', 'AZ', 'AZE', '31', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (268, 'Bahrain', 'Bahrain', 'BH', 'BHR', '48', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (274, 'Bangladesh', 'Bangladesh', 'BD', 'BGD', '50', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (21, 'Barbados', 'Barbados', 'BB', 'BRB', '52', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (22, 'Belarus', 'Belarus', 'BY', 'BLR', '112', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (23, 'Belgium', 'Belgium', 'BE', 'BEL', '56', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (24, 'Belize', 'Belize', 'BZ', 'BLZ', '84', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (277, 'Benin', 'Benin', 'BJ', 'BEN', '204', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (26, 'Bhutan', 'Bhutan', 'BT', 'BTN', '64', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (29, 'Botswana', 'Botswana', 'BW', 'BWA', '72', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (36, 'Brazil', 'Brazil', 'BR', 'BRA', '76', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (44, 'Bulgaria', 'Bulgaria', 'BG', 'BGR', '100', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (45, 'Burkina Faso', 'Burkina Faso', 'BF', 'BFA', '854', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (46, 'Burundi', 'Burundi', 'BI', 'BDI', '108', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (47, 'Cabo Verde', 'Cabo Verde', 'CV', 'CPV', '132', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (65, 'Demchok (disp)', 'Demchok (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (132, 'Kosovo', 'Republic of Kosovo', 'XK', 'XKX', '900', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (71, 'Dragonja (disp)', 'Dragonja (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (72, 'Dramana-Shakatoe (disp)', 'Dramana-Shakatoe (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (126, 'Isla Brasilera (disp)', 'Isla Brasilera (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (116, 'Kalapani (disp)', 'Kalapani (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (143, 'Koualou (disp)', 'Koualou (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (48, 'Cambodia', 'Cambodia', 'KH', 'KHM', '116', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (49, 'Cameroon', 'Cameroon', 'CM', 'CMR', '120', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (227, 'St Barthelemy (Fr)', 'Saint Barthélemy', 'BL', 'BLM', '652', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (228, 'St Helena (UK)', 'Saint Helena, Ascension and Tristan da Cunha', 'SH', 'SHN', '654', false,
                    false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (230, 'St Kitts & Nevis', 'Saint Kitts and Nevis', 'KN', 'KNA', '659', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (149, 'Liancourt Rocks (disp)', 'Liancourt Rocks (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (188, 'Paracel Is (disp)', 'Paracel Is (disp)', 'XX', 'XXX', '999', null, null);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (262, 'West Bank (disp)', 'Palestine, State of', 'PS', 'PSE', '275', false, true);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (231, 'St Lucia', 'Saint Lucia', 'LC', 'LCA', '662', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (232, 'St Martin (Fr)', 'Saint Martin (French part)', 'MF', 'MAF', '663', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (233, 'St Pierre & Miquelon (Fr)', 'Saint Pierre and Miquelon', 'PM', 'SPM', '666', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (234, 'St Vincent & the Grenadines', 'Saint Vincent and the Grenadines', 'VC', 'VCT', '670', true,
                    false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (241, 'Syria', 'Syrian Arab Republic', 'SY', 'SYR', '760', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (198, 'Reunion (Fr)', 'Réunion', 'RE', 'REU', '638', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (238, 'Swaziland', 'Eswatini', 'SZ', 'SWZ', '748', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (257, 'Vatican City', 'Holy See', 'VA', 'VAT', '336', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (259, 'Vietnam', 'Viet Nam', 'VN', 'VNM', '704', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (178, 'Niue (NZ)', 'Niue', 'NU', 'NIU', '570', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (254, 'US Virgin Is (US)', 'Virgin Islands (U.S.)', 'VI', 'VIR', '850', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (202, 'S Georgia & S Sandwich Is (UK)', 'South Georgia and the South Sandwich Islands', 'GS', 'SGS',
                    '239', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (106, 'Navassa I (US)', 'United States Minor Outlying Islands', 'UM', 'UMI', '581', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (253, 'US Minor Pacific Is. Refuges (US)', 'United States Minor Outlying Islands', 'UM', 'UMI',
                    '581', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (260, 'Wake I (US)', 'United States Minor Outlying Islands', 'UM', 'UMI', '581', false, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (77, 'Eritrea', 'Eritrea', 'ER', 'ERI', '232', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (78, 'Estonia', 'Estonia', 'EE', 'EST', '233', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (79, 'Ethiopia', 'Ethiopia', 'ET', 'ETH', '231', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (82, 'Fiji', 'Fiji', 'FJ', 'FJI', '242', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (83, 'Finland', 'Finland', 'FI', 'FIN', '246', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (85, 'France', 'France', 'FR', 'FRA', '250', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (88, 'Gabon', 'Gabon', 'GA', 'GAB', '266', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (95, 'Georgia', 'Georgia', 'GE', 'GEO', '268', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (96, 'Germany', 'Germany', 'DE', 'DEU', '276', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (97, 'Ghana', 'Ghana', 'GH', 'GHA', '288', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (99, 'Greece', 'Greece', 'GR', 'GRC', '300', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (101, 'Grenada', 'Grenada', 'GD', 'GRD', '308', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (105, 'Guatemala', 'Guatemala', 'GT', 'GTM', '320', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (120, 'Hungary', 'Hungary', 'HU', 'HUN', '348', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (121, 'Iceland', 'Iceland', 'IS', 'ISL', '352', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (276, 'India', 'India', 'IN', 'IND', '356', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (122, 'Indonesia', 'Indonesia', 'ID', 'IDN', '360', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (124, 'Iraq', 'Iraq', 'IQ', 'IRQ', '368', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (125, 'Ireland', 'Ireland', 'IE', 'IRL', '372', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (273, 'Israel', 'Israel', 'IL', 'ISR', '376', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (139, 'Italy', 'Italy', 'IT', 'ITA', '380', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (140, 'Jamaica', 'Jamaica', 'JM', 'JAM', '388', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (142, 'Japan', 'Japan', 'JP', 'JPN', '392', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (115, 'Jordan', 'Jordan', 'JO', 'JOR', '400', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (127, 'Kazakhstan', 'Kazakhstan', 'KZ', 'KAZ', '398', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (128, 'Kenya', 'Kenya', 'KE', 'KEN', '404', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (129, 'Kiribati', 'Kiribati', 'KI', 'KIR', '296', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (269, 'Kuwait', 'Kuwait', 'KW', 'KWT', '414', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (144, 'Kyrgyzstan', 'Kyrgyzstan', 'KG', 'KGZ', '417', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (146, 'Latvia', 'Latvia', 'LV', 'LVA', '428', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (147, 'Lebanon', 'Lebanon', 'LB', 'LBN', '422', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (148, 'Lesotho', 'Lesotho', 'LS', 'LSO', '426', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (150, 'Liberia', 'Liberia', 'LR', 'LBR', '430', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (151, 'Libya', 'Libya', 'LY', 'LBY', '434', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (152, 'Liechtenstein', 'Liechtenstein', 'LI', 'LIE', '438', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (153, 'Lithuania', 'Lithuania', 'LT', 'LTU', '440', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (154, 'Luxembourg', 'Luxembourg', 'LU', 'LUX', '442', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (160, 'Madagascar', 'Madagascar', 'MG', 'MDG', '450', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (161, 'Malawi', 'Malawi', 'MW', 'MWI', '454', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (162, 'Malaysia', 'Malaysia', 'MY', 'MYS', '458', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (163, 'Maldives', 'Maldives', 'MV', 'MDV', '462', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (164, 'Mali', 'Mali', 'ML', 'MLI', '466', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (165, 'Malta', 'Malta', 'MT', 'MLT', '470', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (168, 'Mauritania', 'Mauritania', 'MR', 'MRT', '478', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (169, 'Mauritius', 'Mauritius', 'MU', 'MUS', '480', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (171, 'Mexico', 'Mexico', 'MX', 'MEX', '484', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (155, 'Monaco', 'Monaco', 'MC', 'MCO', '492', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (156, 'Mongolia', 'Mongolia', 'MN', 'MNG', '496', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (157, 'Montenegro', 'Montenegro', 'ME', 'MNE', '499', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (91, 'Morocco', 'Morocco', 'MA', 'MAR', '504', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (92, 'Mozambique', 'Mozambique', 'MZ', 'MOZ', '508', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (93, 'Namibia', 'Namibia', 'NA', 'NAM', '516', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (103, 'Nauru', 'Nauru', 'NR', 'NRU', '520', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (107, 'Nepal', 'Nepal', 'NP', 'NPL', '524', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (108, 'Netherlands', 'Netherlands', 'NL', 'NLD', '528', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (176, 'New Zealand', 'New Zealand', 'NZ', 'NZL', '554', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (177, 'Nicaragua', 'Nicaragua', 'NI', 'NIC', '558', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (278, 'Niger', 'Niger', 'NE', 'NER', '562', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (279, 'Nigeria', 'Nigeria', 'NG', 'NGA', '566', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (182, 'Norway', 'Norway', 'NO', 'NOR', '578', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (183, 'Oman', 'Oman', 'OM', 'OMN', '512', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (184, 'Pakistan', 'Pakistan', 'PK', 'PAK', '586', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (185, 'Palau', 'Palau', 'PW', 'PLW', '585', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (186, 'Panama', 'Panama', 'PA', 'PAN', '591', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (187, 'Papua New Guinea', 'Papua New Guinea', 'PG', 'PNG', '598', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (189, 'Paraguay', 'Paraguay', 'PY', 'PRY', '600', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (190, 'Peru', 'Peru', 'PE', 'PER', '604', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (191, 'Philippines', 'Philippines', 'PH', 'PHL', '608', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (193, 'Poland', 'Poland', 'PL', 'POL', '616', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (194, 'Portugal', 'Portugal', 'PT', 'PRT', '620', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (270, 'Qatar', 'Qatar', 'QA', 'QAT', '634', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (199, 'Romania', 'Romania', 'RO', 'ROU', '642', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (201, 'Rwanda', 'Rwanda', 'RW', 'RWA', '646', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (203, 'Samoa', 'Samoa', 'WS', 'WSM', '882', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (204, 'San Marino', 'San Marino', 'SM', 'SMR', '674', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (212, 'Saudi Arabia', 'Saudi Arabia', 'SA', 'SAU', '682', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (213, 'Senegal', 'Senegal', 'SN', 'SEN', '686', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (133, 'Serbia', 'Serbia', 'RS', 'SRB', '688', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (134, 'Seychelles', 'Seychelles', 'SC', 'SYC', '690', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (136, 'Sierra Leone', 'Sierra Leone', 'SL', 'SLE', '694', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (137, 'Singapore', 'Singapore', 'SG', 'SGP', '702', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (216, 'Slovakia', 'Slovakia', 'SK', 'SVK', '703', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (217, 'Slovenia', 'Slovenia', 'SI', 'SVN', '705', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (219, 'Somalia', 'Somalia', 'SO', 'SOM', '706', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (220, 'South Africa', 'South Africa', 'ZA', 'ZAF', '710', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (221, 'South Sudan', 'South Sudan', 'SS', 'SSD', '728', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (222, 'Spain', 'Spain', 'ES', 'ESP', '724', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (226, 'Sri Lanka', 'Sri Lanka', 'LK', 'LKA', '144', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (235, 'Sudan', 'Sudan', 'SD', 'SDN', '729', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (236, 'Suriname', 'Suriname', 'SR', 'SUR', '740', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (239, 'Sweden', 'Sweden', 'SE', 'SWE', '752', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (240, 'Switzerland', 'Switzerland', 'CH', 'CHE', '756', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (243, 'Tajikistan', 'Tajikistan', 'TJ', 'TJK', '762', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (245, 'Thailand', 'Thailand', 'TH', 'THA', '764', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (246, 'Timor-Leste', 'Timor-Leste', 'TL', 'TLS', '626', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (247, 'Togo', 'Togo', 'TG', 'TGO', '768', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (206, 'Tonga', 'Tonga', 'TO', 'TON', '776', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (208, 'Tunisia', 'Tunisia', 'TN', 'TUN', '788', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (272, 'Turkey', 'Turkey', 'TR', 'TUR', '792', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (209, 'Turkmenistan', 'Turkmenistan', 'TM', 'TKM', '795', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (248, 'Tuvalu', 'Tuvalu', 'TV', 'TUV', '798', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (249, 'Uganda', 'Uganda', 'UG', 'UGA', '800', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (267, 'Ukraine', 'Ukraine', 'UA', 'UKR', '804', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (271, 'United Arab Emirates', 'United Arab Emirates', 'AE', 'ARE', '784', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (252, 'Uruguay', 'Uruguay', 'UY', 'URY', '858', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (255, 'Uzbekistan', 'Uzbekistan', 'UZ', 'UZB', '860', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (256, 'Vanuatu', 'Vanuatu', 'VU', 'VUT', '548', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (266, 'Yemen', 'Yemen', 'YE', 'YEM', '887', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (264, 'Zambia', 'Zambia', 'ZM', 'ZMB', '894', true, false);
            INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code,
                                    iso_independent, inferred_match)
            VALUES (265, 'Zimbabwe', 'Zimbabwe', 'ZW', 'ZWE', '716', true, false);


            insert into static.country(iso2c, iso3c, country)
            select iso_alpha2_code, iso_alpha3_code, cc_name
            from iso_lookup;

            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (1, NULL, '48', 'TX', 'Texas');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (2, NULL, '06', 'CA', 'California');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (14, NULL, '02', 'AK', 'Alaska');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (3, NULL, '21', 'KY', 'Kentucky');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (49, NULL, '50', 'VT', 'Vermont');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (4, NULL, '13', 'GA', 'Georgia');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (17, NULL, '31', 'NE', 'Nebraska');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (5, NULL, '55', 'WI', 'Wisconsin');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (6, NULL, '41', 'OR', 'Oregon');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (18, NULL, '53', 'WA', 'Washington');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (7, NULL, '51', 'VA', 'Virginia');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (50, NULL, '34', 'NJ', 'New Jersey');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (8, NULL, '47', 'TN', 'Tennessee');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (19, NULL, '39', 'OH', 'Ohio');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (9, NULL, '22', 'LA', 'Louisiana');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (38, NULL, '01', 'AL', 'Alabama');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (10, NULL, '36', 'NY', 'New York');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (39, NULL, '72', 'PR', 'Puerto Rico');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (11, NULL, '26', 'MI', 'Michigan');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (12, NULL, '16', 'ID', 'Idaho');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (24, NULL, '05', 'AR', 'Arkansas');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (13, NULL, '12', 'FL', 'Florida');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (15, NULL, '30', 'MT', 'Montana');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (25, NULL, '28', 'MS', 'Mississippi');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (16, NULL, '27', 'MN', 'Minnesota');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (26, NULL, '08', 'CO', 'Colorado');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (37, NULL, '44', 'RI', 'Rhode Island');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (20, NULL, '17', 'IL', 'Illinois');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (21, NULL, '29', 'MO', 'Missouri');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (44, NULL, '35', 'NM', 'New Mexico');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (22, NULL, '19', 'IA', 'Iowa');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (23, NULL, '46', 'SD', 'South Dakota');
            INSERT INTO static.states (id, country_id, fips, abb, state)
            VALUES (27, NULL, '37', 'NC', 'North Carolina');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (28, NULL, '49', 'UT', 'Utah');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (51, NULL, '38', 'ND', 'North Dakota');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (29, NULL, '40', 'OK', 'Oklahoma');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (30, NULL, '56', 'WY', 'Wyoming');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (52, NULL, '33', 'NH', 'New Hampshire');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (31, NULL, '54', 'WV', 'West Virginia');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (32, NULL, '18', 'IN', 'Indiana');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (33, NULL, '25', 'MA', 'Massachusetts');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (34, NULL, '32', 'NV', 'Nevada');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (35, NULL, '09', 'CT', 'Connecticut');
            INSERT INTO static.states (id, country_id, fips, abb, state)
            VALUES (36, NULL, '11', 'DC', 'District of Columbia');
            INSERT INTO static.states (id, country_id, fips, abb, state)
            VALUES (40, NULL, '45', 'SC', 'South Carolina');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (41, NULL, '23', 'ME', 'Maine');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (42, NULL, '15', 'HI', 'Hawaii');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (43, NULL, '04', 'AZ', 'Arizona');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (46, NULL, '10', 'DE', 'Delaware');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (45, NULL, '24', 'MD', 'Maryland');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (47, NULL, '42', 'PA', 'Pennsylvania');
            INSERT INTO static.states (id, country_id, fips, abb, state) VALUES (48, NULL, '20', 'KS', 'Kansas');

            update static.states set country_id = (select id from static.country where country = 'United States');

            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1, 'Grand Isle', 49, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2, 'Izard', 24, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3, 'Marshall', 20, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (4, 'Benton', 22, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (5, 'Waseca', 16, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (6, 'Miami', 19, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (7, 'Jerauld', 23, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (8, 'Glasscock', 1, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (9, 'Greene', 7, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (10, 'Loíza', 39, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (11, 'Naranjito', 39, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (12, 'Otero', 26, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (13, 'Sharp', 24, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (14, 'Stevens', 48, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (15, 'Manistee', 11, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (16, 'Preble', 19, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (17, 'Hickman', 3, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (18, 'Lake', 23, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (19, 'Yuba', 2, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (20, 'Washtenaw', 11, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (21, 'Rush', 32, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (22, 'Montmorency', 11, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (23, 'Oklahoma', 29, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (24, 'Carbon', 47, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (25, 'Franklin', 48, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (26, 'Orange', 1, '361', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (27, 'Manassas Park', 7, '685', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (28, 'Eau Claire', 5, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (29, 'Union', 32, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (30, 'Prentiss', 25, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (31, 'Marion', 19, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (32, 'Polk', 4, '233', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (33, 'Hamilton', 48, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (34, 'Dawes', 17, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (35, 'Renville', 51, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (36, 'Barren', 3, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (37, 'King William', 7, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (38, 'Treutlen', 4, '283', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (39, 'Bedford', 8, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (40, 'Falls', 1, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (41, 'Swisher', 1, '437', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (42, 'Waupaca', 5, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (43, 'Cataño', 39, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (44, 'Trego', 48, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (45, 'Stone', 25, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (46, 'Logan', 51, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (47, 'Lynn', 1, '305', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (48, 'Hardin', 3, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (49, 'Cass', 11, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (50, 'Barton', 21, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (51, 'Scotts Bluff', 17, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (52, 'Louisa', 7, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (53, 'Miller', 4, '201', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (54, 'Cumberland', 20, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (55, 'Ripley', 32, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (56, 'Lincoln', 25, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (57, 'Maury', 8, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (58, 'Franklin', 1, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (59, 'Kenton', 3, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (60, 'Douglas', 20, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (61, 'Parker', 1, '367', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (62, 'Hansford', 1, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (63, 'Rock', 16, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (64, 'Clay', 22, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (65, 'Pima', 43, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (66, 'Cheboygan', 11, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (67, 'Eddy', 44, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (68, 'Duval', 13, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (69, 'Marion', 32, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (70, 'Boone', 32, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (71, 'Lubbock', 1, '303', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (72, 'Knox', 3, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (73, 'Livingston', 20, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (74, 'O''Brien', 22, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (75, 'Florence', 40, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (76, 'Wyandot', 19, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (77, 'Cayey', 39, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (78, 'Thomas', 48, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (79, 'Culebra', 39, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (80, 'Ohio', 32, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (81, 'Polk', 27, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (82, 'Clay', 17, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (83, 'Roseau', 16, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (84, 'Pendleton', 3, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (85, 'Richardson', 17, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (86, 'Adams', 47, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (87, 'Charles City', 7, '036', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (88, 'Dickens', 1, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (89, 'Bond', 20, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (90, 'Rooks', 48, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (91, 'Newton', 25, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (92, 'Wheeler', 17, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (93, 'Jack', 1, '237', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (94, 'Galax', 7, '640', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (95, 'Lincoln', 5, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (96, 'Butte', 12, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (97, 'Iowa', 22, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (98, 'Ringgold', 22, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (99, 'Nacogdoches', 1, '347', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (100, 'Norton', 48, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (101, 'Greene', 25, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (102, 'McKinley', 44, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (103, 'Ohio', 31, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (104, 'Clay', 38, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (105, 'Terrell', 4, '273', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (106, 'Stark', 20, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (107, 'Butler', 48, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (108, 'Gentry', 21, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (109, 'Crawford', 19, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (110, 'Woodward', 29, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (111, 'Saluda', 40, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (112, 'Eastland', 1, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (113, 'Crawford', 11, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (114, 'Brown', 23, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (115, 'Macoupin', 20, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (116, 'Webster', 22, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (117, 'Warren', 8, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (118, 'Cimarron', 29, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (119, 'Marion', 38, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (120, 'Canyon', 12, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (121, 'Rockingham', 27, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (122, 'Beaver', 47, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (123, 'Sanborn', 23, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (124, 'Jeff Davis', 4, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (125, 'White', 4, '311', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (126, 'Fayette', 3, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (127, 'Billings', 51, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (128, 'Maricao', 39, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (129, 'Yabucoa', 39, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (130, 'Ouray', 26, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (131, 'Clay', 32, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (132, 'Ida', 22, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (133, 'Simpson', 25, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (134, 'Brown', 17, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (135, 'Dickenson', 7, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (136, 'District of Columbia', 36, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (137, 'Staunton', 7, '790', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (138, 'Martin', 16, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (139, 'Yadkin', 27, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (140, 'Kossuth', 22, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (141, 'Mecklenburg', 7, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (142, 'Vermillion', 32, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (143, 'Potter', 1, '375', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (144, 'LaPorte', 32, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (145, 'Gooding', 12, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (146, 'Outagamie', 5, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (147, 'Richland', 20, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (148, 'Hyde', 23, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (149, 'New Hanover', 27, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (150, 'Chickasaw', 22, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (151, 'White', 20, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (152, 'Robertson', 8, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (153, 'Barry', 21, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (154, 'Rock', 5, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (155, 'Rusk', 5, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (156, 'Taylor', 5, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (157, 'Waukesha', 5, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (158, 'Quitman', 4, '239', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (159, 'Cape Girardeau', 21, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (160, 'Pipestone', 16, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (161, 'Wheatland', 15, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (162, 'Steele', 16, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (163, 'Fayette', 38, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (164, 'Cloud', 48, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (165, 'Clinton', 32, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (166, 'Clinton', 20, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (167, 'Worth', 4, '321', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (168, 'Phillips', 48, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (169, 'McDonald', 21, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (170, 'Belknap', 52, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (171, 'Cass', 51, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (172, 'Clark', 19, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (173, 'Pierce', 17, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (174, 'Kenosha', 5, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (175, 'Swift', 16, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (176, 'Smyth', 7, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (177, 'Nelson', 51, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (178, 'Fredericksburg', 7, '630', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (179, 'Garland', 24, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (180, 'Stoddard', 21, '207', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (181, 'Crawford', 48, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (182, 'Childress', 1, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (183, 'Cottle', 1, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (184, 'Emmet', 22, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (185, 'Elk', 48, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (186, 'Gratiot', 11, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (187, 'Worth', 22, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (188, 'Ionia', 11, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (189, 'McLean', 3, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (190, 'Montgomery', 3, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (191, 'Mecosta', 11, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (192, 'Wadena', 16, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (193, 'Dodge', 16, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (194, 'Oceana', 11, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (195, 'Franklin', 20, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (196, 'Benton', 16, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (197, 'Douglas', 16, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (198, 'Butler', 3, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (199, 'Anderson', 40, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (200, 'Archer', 1, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (201, 'Deuel', 23, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (202, 'Skagway', 14, '230', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (203, 'Hancock', 8, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (204, 'Humphreys', 8, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (205, 'Pulaski', 32, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (206, 'Kittson', 16, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (207, 'Grundy', 20, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (208, 'Hickory', 21, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (209, 'Karnes', 1, '255', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (210, 'Colfax', 17, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (211, 'Hamilton', 1, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (212, 'Kidder', 51, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (213, 'Steele', 51, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (214, 'Dodge', 17, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (215, 'Brown', 48, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (216, 'Pike', 24, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (217, 'Brown', 1, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (218, 'Harvey', 48, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (219, 'Bastrop', 1, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (220, 'Atkinson', 4, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (221, 'Spokane', 18, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (222, 'Oscoda', 11, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (223, 'Echols', 4, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (224, 'Sutton', 1, '435', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (225, 'Thurston', 17, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (226, 'Arroyo', 39, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (227, 'Carlton', 16, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (228, 'Caldwell', 21, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (229, 'Putnam', 8, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (230, 'Irwin', 4, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (231, 'Eddy', 51, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (232, 'Grant', 48, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (233, 'Atchison', 48, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (234, 'St. James', 9, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (235, 'Person', 27, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (236, 'Highlands', 13, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (237, 'Madison', 19, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (238, 'Labette', 48, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (239, 'Newton', 32, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (240, 'Davis', 22, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (241, 'Kit Carson', 26, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (242, 'Chambers', 38, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (243, 'Osage', 48, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (244, 'Butts', 4, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (245, 'Phillips', 26, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (246, 'Gloucester', 7, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (247, 'Clarke', 4, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (248, 'Sedgwick', 26, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (249, 'Union', 20, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (250, 'Seneca', 19, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (251, 'Terry', 1, '445', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (252, 'Trumbull', 19, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (253, 'Carroll', 20, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (254, 'Fayette', 19, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (255, 'Butler', 19, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (256, 'Winston', 38, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (257, 'Jackson', 1, '239', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (258, 'Stephens', 4, '257', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (259, 'Rice', 16, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (260, 'Mayes', 29, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (261, 'Meeker', 16, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (262, 'Rockwall', 1, '397', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (263, 'Tate', 25, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (264, 'Okfuskee', 29, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (265, 'Adams', 17, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (266, 'Somervell', 1, '425', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (267, 'Warren', 4, '301', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (268, 'Howard', 21, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (269, 'Linn', 21, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (270, 'Glascock', 4, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (271, 'Greene', 4, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (272, 'Marathon', 5, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (273, 'Bristol Bay', 14, '060', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (274, 'Marshall', 16, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (275, 'Davison', 23, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (276, 'Pickaway', 19, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (277, 'Hopkins', 1, '223', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (278, 'Hartley', 1, '205', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (279, 'Sullivan', 10, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (280, 'Tioga', 10, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (281, 'Fulton', 10, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (282, 'Morgan', 38, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (283, 'Lamar', 38, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (284, 'Gulf', 13, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (285, 'Leon', 13, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (286, 'Dade', 4, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (287, 'Mitchell', 4, '205', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (288, 'Calhoun', 25, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (289, 'Lewis', 18, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (290, 'Rincón', 39, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (291, 'Pickens', 38, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (292, 'Bourbon', 48, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (293, 'Johnson', 4, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (294, 'Isanti', 16, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (295, 'Toa Alta', 39, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (296, 'Conejos', 26, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (297, 'Sherman', 17, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (298, 'Lawrence', 32, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (299, 'Clark', 23, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (300, 'Pendleton', 31, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (301, 'Schuyler', 21, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (302, 'Marion', 31, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (303, 'Fulton', 19, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (304, 'Aguas Buenas', 39, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (305, 'Covington', 25, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (306, 'Warren', 20, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (307, 'Wright', 22, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (308, 'Lincoln', 48, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (309, 'Alpena', 11, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (310, 'Guayanilla', 39, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (311, 'Genesee', 11, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (312, 'Sabana Grande', 39, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (313, 'Cavalier', 51, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (314, 'Wells', 32, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (315, 'Howard', 32, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (316, 'Logan', 19, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (317, 'Polk', 21, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (318, 'Ogle', 20, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (319, 'Graham', 48, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (320, 'Lane', 48, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (321, 'Rolette', 51, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (322, 'Dane', 5, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (323, 'Lewis', 10, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (324, 'Van Buren', 24, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (325, 'Blanco', 1, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (326, 'Rockland', 10, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (327, 'Norfolk', 7, '710', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (328, 'Stone', 24, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (329, 'Pueblo', 26, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (330, 'Ward', 1, '475', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (331, 'Saguache', 26, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (332, 'Kent', 1, '263', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (333, 'Boone', 24, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (334, 'Adair', 29, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (335, 'Franklin', 24, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (336, 'Martin', 32, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (337, 'Marshall', 25, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (338, 'Macon', 8, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (339, 'Briscoe', 1, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (340, 'Fillmore', 16, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (341, 'Kinney', 1, '271', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (342, 'Greensville', 7, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (343, 'Jenkins', 4, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (344, 'Walsh', 51, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (345, 'Putnam', 31, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (346, 'St. Clair', 21, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (347, 'Sunflower', 25, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (348, 'Stephens', 1, '429', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (349, 'Hall', 17, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (350, 'Nemaha', 17, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (351, 'Trousdale', 8, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (352, 'San Francisco', 2, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (353, 'Harlan', 17, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (354, 'Fall River', 23, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (355, 'Oldham', 1, '359', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (356, 'Rapides', 9, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (357, 'Trimble', 3, '223', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (358, 'Pope', 16, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (359, 'DeKalb', 32, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (360, 'Iroquois', 20, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (361, 'Cobb', 4, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (362, 'Montour', 47, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (363, 'Winkler', 1, '495', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (364, 'Lawrence', 23, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (365, 'Parke', 32, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (366, 'King', 1, '269', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (367, 'Emporia', 7, '595', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (368, 'Putnam', 20, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (369, 'Jefferson', 17, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (370, 'Iosco', 11, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (371, 'Richmond', 27, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (372, 'Brown', 20, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (373, 'Adams', 22, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (374, 'Stark', 51, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (375, 'Lynchburg', 7, '680', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (376, 'Calhoun', 4, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (377, 'Crockett', 8, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (378, 'Lexington', 7, '678', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (379, 'Worcester', 45, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (380, 'Daggett', 28, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (381, 'Hamilton', 13, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (382, 'Huntington', 32, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (383, 'Boone', 17, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (384, 'Sawyer', 5, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (385, 'Suffolk', 7, '800', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (386, 'Jefferson Davis', 25, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (387, 'Hamilton', 17, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (388, 'Traverse', 16, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (389, 'Bland', 7, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (390, 'Hardeman', 8, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (391, 'Woodson', 48, '207', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (392, 'Ford', 20, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (393, 'Hamilton', 32, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (394, 'Yankton', 23, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (395, 'Kingsbury', 23, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (396, 'Montgomery', 24, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (397, 'Trujillo Alto', 39, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (398, 'Hubbard', 16, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (399, 'Sargent', 51, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (400, 'Dickinson', 48, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (401, 'Taylor', 31, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (402, 'Livingston', 9, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (403, 'Hettinger', 51, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (404, 'Marshall', 48, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (405, 'Luce', 11, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (406, 'Blaine', 29, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (407, 'Mitchell', 1, '335', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (408, 'Keya Paha', 17, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (409, 'Sheridan', 15, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (410, 'Sandusky', 19, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (411, 'Randolph', 21, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (412, 'Carroll', 4, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (413, 'Thomas', 17, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (414, 'Loudon', 8, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (415, 'Tipton', 32, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (416, 'Barry', 11, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (417, 'Corozal', 39, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (418, 'Alamosa', 26, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (419, 'McDonough', 20, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (420, 'Runnels', 1, '399', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (421, 'Franklin', 4, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (422, 'Wheeler', 1, '483', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (423, 'Pulaski', 20, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (424, 'Palo Pinto', 1, '363', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (425, 'Choctaw', 25, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (426, 'Pratt', 48, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (427, 'Cabell', 31, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (428, 'Franklin', 25, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (429, 'Baker', 4, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (430, 'Otsego', 11, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (431, 'Hockley', 1, '219', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (432, 'Shelby', 22, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (433, 'Marion', 3, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (434, 'Calumet', 5, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (435, 'Bowman', 51, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (436, 'Grant', 32, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (437, 'Schuyler', 10, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (438, 'Turner', 23, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (439, 'Fayette', 8, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (440, 'Andrew', 21, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (441, 'Chester', 40, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (442, 'Winneshiek', 22, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (443, 'Hillsdale', 11, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (444, 'Pennington', 16, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (445, 'Stafford', 48, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (446, 'DeWitt', 1, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (447, 'Lincoln', 29, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (448, 'Baldwin', 4, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (449, 'Doddridge', 31, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (450, 'Wayne', 22, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (451, 'Clayton', 4, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (452, 'Johnson', 17, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (453, 'Sac', 22, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (454, 'Titus', 1, '449', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (455, 'Bennett', 23, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (456, 'Warren', 32, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (457, 'Cerro Gordo', 22, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (458, 'Ozaukee', 5, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (459, 'Madison', 32, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (460, 'Kendall', 20, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (461, 'Schuylkill', 47, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (462, 'Barnes', 51, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (463, 'Logan', 24, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (464, 'Kosciusko', 32, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (465, 'Salem', 7, '775', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (466, 'Kearny', 48, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (467, 'LaSalle', 20, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (468, 'Lafayette', 21, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (469, 'Faribault', 16, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (470, 'Cherokee', 22, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (471, 'Geary', 48, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (472, 'Tippecanoe', 32, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (473, 'Union', 4, '291', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (474, 'Roanoke City', 7, '770', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (475, 'Twin Falls', 12, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (476, 'Washington', 48, '201', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (477, 'Osceola', 22, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (478, 'Morehouse', 9, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (479, 'Clark', 21, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (480, 'Worth', 21, '227', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (481, 'Powder River', 15, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (482, 'Bristol', 7, '520', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (483, 'Woodford', 3, '239', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (484, 'Deuel', 17, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (485, 'Caldwell', 27, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (486, 'Irion', 1, '235', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (487, 'Ogemaw', 11, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (488, 'Scott', 20, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (489, 'Grant', 29, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (490, 'Carroll', 3, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (491, 'Pepin', 5, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (492, 'Morgan', 26, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (493, 'Benton', 32, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (494, 'Alamance', 27, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (495, 'Haralson', 4, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (496, 'Fayette', 22, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (497, 'Brookings', 23, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (498, 'Palo Alto', 22, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (499, 'McNairy', 8, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (500, 'Campbell', 30, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (501, 'Weakley', 8, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (502, 'Pocahontas', 22, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (503, 'Hayes', 17, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (504, 'Tioga', 47, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (505, 'Carroll', 22, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (506, 'Duval', 1, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (507, 'Madison', 8, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (508, 'Vernon', 21, '217', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (509, 'Ben Hill', 4, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (510, 'Washington', 26, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (511, 'Evans', 4, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (512, 'Forsyth', 4, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (513, 'Sherburne', 16, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (514, 'Attala', 25, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (515, 'Brooke', 31, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (516, 'Mineral', 31, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (517, 'Fayette', 32, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (518, 'Quitman', 25, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (519, 'Lenawee', 11, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (520, 'Clay', 48, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (521, 'Johnson', 21, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (522, 'Chautauqua', 48, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (523, 'Benewah', 12, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (524, 'Schuyler', 20, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (525, 'Mille Lacs', 16, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (526, 'Rhea', 8, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (527, 'Burleigh', 51, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (528, 'Carter', 29, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (529, 'Eureka', 34, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (530, 'Santa Cruz', 43, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (531, 'Randolph', 24, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (532, 'Darke', 19, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (533, 'Georgetown', 40, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (534, 'Marion', 1, '315', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (535, 'Clay', 21, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (536, 'Newport News', 7, '700', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (537, 'Lyon', 48, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (538, 'Livingston', 3, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (539, 'Montgomery', 45, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (540, 'Lincoln', 16, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (541, 'Graham', 27, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (542, 'Dutchess', 10, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (543, 'Westchester', 10, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (544, 'Campbell', 8, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (545, 'Chambers', 1, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (546, 'Hidalgo', 1, '215', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (547, 'Westmoreland', 7, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (548, 'Perry', 20, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (549, 'Escambia', 13, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (550, 'Dunn', 51, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (551, 'Villalba', 39, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (552, 'Calcasieu', 9, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (553, 'Iron', 28, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (554, 'Weld', 26, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (555, 'Aleutians East', 14, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (556, 'Plumas', 2, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (557, 'Wilkes', 4, '317', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (558, 'Jasper', 4, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (559, 'Craighead', 24, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (560, 'Rush', 48, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (561, 'Palm Beach', 13, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (562, 'Wilkin', 16, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (563, 'Knox', 32, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (564, 'Gibson', 32, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (565, 'Butler', 38, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (566, 'Sumter', 40, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (567, 'Powhatan', 7, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (568, 'Roane', 8, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (569, 'Burleson', 1, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (570, 'Henry', 8, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (571, 'Navarro', 1, '349', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (572, 'Franklin', 8, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (573, 'Hancock', 20, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (574, 'Big Horn', 15, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (575, 'Elliott', 3, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (576, 'Bethel', 14, '050', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (577, 'Arkansas', 24, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (578, 'Douglas', 26, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (579, 'Kalawao', 42, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (580, 'Jefferson Davis', 9, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (581, 'Kiowa', 48, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (582, 'Wake', 27, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (583, 'Edgecombe', 27, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (584, 'Morrill', 17, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (585, 'Shelby', 19, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (586, 'Carroll', 19, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (587, 'St. Croix', 5, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (588, 'Wayne', 4, '305', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (589, 'Sabine', 1, '403', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (590, 'Door', 5, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (591, 'Lee', 20, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (592, 'Gila', 43, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (593, 'Liberty', 13, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (594, 'Putnam', 4, '237', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (595, 'Marion', 22, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (596, 'Reynolds', 21, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (597, 'Evangeline', 9, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (598, 'Clinton', 11, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (599, 'Redwood', 16, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (600, 'Texas', 21, '215', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (601, 'Phelps', 17, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (602, 'Valencia', 44, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (603, 'Rowan', 27, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (604, 'Honolulu', 42, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (605, 'Garrard', 3, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (606, 'Lapeer', 11, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (607, 'Neshoba', 25, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (608, 'Pondera', 15, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (609, 'Blaine', 17, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (610, 'Lenoir', 27, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (611, 'McHenry', 51, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (612, 'Seminole', 29, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (613, 'Canadian', 29, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (614, 'Snyder', 47, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (615, 'Williamsburg', 40, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (616, 'Grimes', 1, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (617, 'Jefferson', 1, '245', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (618, 'Coleman', 1, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (619, 'Lewis', 31, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (620, 'Hot Springs', 30, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (621, 'Williamson', 20, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (622, 'Moffat', 26, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (623, 'Grant', 18, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (624, 'Shelby', 3, '211', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (625, 'Lamb', 1, '279', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (626, 'Perry', 3, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (627, 'Waller', 1, '473', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (628, 'Crisp', 4, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (629, 'Wibaux', 15, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (630, 'Dawson', 1, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (631, 'Avoyelles', 9, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (632, 'Gaines', 1, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (633, 'Wexford', 11, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (634, 'Little River', 24, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (635, 'Muscogee', 4, '215', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (636, 'Cassia', 12, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (637, 'Franklin', 32, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (638, 'Houston', 16, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (639, 'Pearl River', 25, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (640, 'Cheyenne', 17, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (641, 'Clinton', 10, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (642, 'Lee', 27, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (643, 'Ottawa', 19, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (644, 'Crawford', 4, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (645, 'Morrow', 6, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (646, 'McKean', 47, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (647, 'Windham', 49, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (648, 'Dale', 38, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (649, 'Henry', 20, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (650, 'Hendricks', 32, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (651, 'Green', 3, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (652, 'Knox', 8, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (653, 'Bee', 1, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (654, 'Ottawa', 11, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (655, 'Benson', 51, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (656, 'San Germán', 39, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (657, 'Fond du Lac', 5, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (658, 'Converse', 30, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (659, 'Lewis', 12, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (660, 'Minidoka', 12, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (661, 'Jefferson', 20, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (662, 'Slope', 51, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (663, 'Greenbrier', 31, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (664, 'Río Grande', 39, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (665, 'Dunklin', 21, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (666, 'Paulding', 19, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (667, 'Beauregard', 9, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (668, 'Garfield', 17, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (669, 'East Baton Rouge', 9, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (670, 'St. John the Baptist', 9, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (671, 'Buffalo', 17, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (672, 'Los Alamos', 44, '028', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (673, 'Seneca', 10, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (674, 'Breathitt', 3, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (675, 'Pike', 19, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (676, 'Grant', 6, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (677, 'Union', 8, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (678, 'Towner', 51, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (679, 'Martinsville', 7, '690', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (680, 'Sterling', 1, '431', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (681, 'Denton', 1, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (682, 'Tucker', 31, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (683, 'Trempealeau', 5, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (684, 'Juana Díaz', 39, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (685, 'McCormick', 40, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (686, 'Vigo', 32, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (687, 'St. Lucie', 13, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (688, 'Cullman', 38, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (689, 'White', 8, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (690, 'Clinton', 19, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (691, 'Gillespie', 1, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (692, 'Yamhill', 6, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (693, 'Quebradillas', 39, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (694, 'Petersburg', 7, '730', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (695, 'Choctaw', 38, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (696, 'Monterey', 2, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (697, 'Fannin', 4, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (698, 'Calloway', 3, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (699, 'Montgomery', 48, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (700, 'Charlevoix', 11, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (701, 'Newaygo', 11, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (702, 'Delta', 11, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (703, 'McMullen', 1, '311', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (704, 'Jefferson', 10, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (705, 'Jackson', 6, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (706, 'Kent', 37, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (707, 'Gove', 48, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (708, 'Seminole', 4, '253', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (709, 'Lauderdale', 25, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (710, 'Jay', 32, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (711, 'Comanche', 48, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (712, 'Kanabec', 16, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (713, 'Lowndes', 25, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (714, 'DeKalb', 8, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (715, 'Lawrence', 21, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (716, 'Allen', 3, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (717, 'Lyon', 22, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (718, 'Garfield', 15, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (719, 'Grant', 17, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (720, 'Klamath', 6, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (721, 'Botetourt', 7, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (722, 'Benton', 24, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (723, 'Sarasota', 13, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (724, 'Uintah', 28, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (725, 'Menominee', 11, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (726, 'Wyoming', 10, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (727, 'Brule', 23, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (728, 'Geneva', 38, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (729, 'Orange', 2, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (730, 'St. Clair', 20, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (731, 'Benton', 25, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (732, 'Otoe', 17, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (733, 'Sarpy', 17, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (734, 'Hillsborough', 52, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (735, 'Monroe', 10, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (736, 'Divide', 51, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (737, 'Northampton', 47, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (738, 'Kleberg', 1, '273', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (739, 'Henry', 7, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (740, 'Carson', 1, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (741, 'Surry', 7, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (742, 'Faulk', 23, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (743, 'Polk', 8, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (744, 'Garfield', 18, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (745, 'Rappahannock', 7, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (746, 'Westmoreland', 47, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (747, 'Barber', 48, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (748, 'Oconee', 4, '219', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (749, 'Upson', 4, '293', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (750, 'Nome', 14, '180', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (751, 'Clark', 24, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (752, 'Calhoun', 24, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (753, 'Butte', 2, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (754, 'De Witt', 20, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (755, 'Jennings', 32, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (756, 'Lincoln', 3, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (757, 'Lafayette', 25, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (758, 'Morgan', 20, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (759, 'Pend Oreille', 18, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (760, 'Pushmataha', 29, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (761, 'Gem', 12, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (762, 'Lee', 40, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (763, 'Berkeley', 31, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (764, 'Chickasaw', 25, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (765, 'Hill', 15, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (766, 'Boyle', 3, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (767, 'Aroostook', 41, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (768, 'Washington', 25, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (769, 'Boyd', 17, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (770, 'Colfax', 44, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (771, 'Hamilton', 19, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (772, 'Lawrence', 19, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (773, 'Clay', 1, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (774, 'Floyd', 7, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (775, 'Elmore', 38, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (776, 'Lewis', 3, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (777, 'El Paso', 26, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (778, 'Newton', 4, '217', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (779, 'Nicollet', 16, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (780, 'Talbot', 45, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (781, 'Reagan', 1, '383', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (782, 'Lea', 44, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (783, 'Alameda', 2, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (784, 'Grady', 4, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (785, 'Latah', 12, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (786, 'Jo Daviess', 20, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (787, 'Napa', 2, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (788, 'Clay', 13, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (789, 'Arthur', 17, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (790, 'Idaho', 12, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (791, 'Simpson', 3, '213', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (792, 'Antrim', 11, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (793, 'Gogebic', 11, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (794, 'Sheridan', 17, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (795, 'Motley', 1, '345', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (796, 'Codington', 23, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (797, 'Chemung', 10, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (798, 'Erie', 10, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (799, 'Washington', 19, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (800, 'Northampton', 27, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (801, 'Jackson', 21, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (802, 'Bennington', 49, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (803, 'Sacramento', 2, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (804, 'Lonoke', 24, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (805, 'Bristol', 37, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (806, 'Scott', 32, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (807, 'Beltrami', 16, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (808, 'Perry', 25, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (809, 'Leake', 25, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (810, 'Ohio', 3, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (811, 'Socorro', 44, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (812, 'Scurry', 1, '415', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (813, 'Fisher', 1, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (814, 'Gilmer', 31, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (815, 'Limestone', 1, '293', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (816, 'Ceiba', 39, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (817, 'Camas', 12, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (818, 'Knox', 20, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (819, 'Wells', 51, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (820, 'Jessamine', 3, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (821, 'Renville', 16, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (822, 'Bannock', 12, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (823, 'Tuscarawas', 19, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (824, 'Richland', 19, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (825, 'Lebanon', 47, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (826, 'Spink', 23, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (827, 'Bledsoe', 8, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (828, 'Hays', 1, '209', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (829, 'San Lorenzo', 39, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (830, 'Thomas', 4, '275', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (831, 'Dawson', 4, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (832, 'Morgan', 4, '211', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (833, 'Richmond', 10, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (834, 'Caddo', 9, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (835, 'Contra Costa', 2, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (836, 'Pacific', 18, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (837, 'Upshur', 31, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (838, 'Menard', 1, '327', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (839, 'Bullitt', 3, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (840, 'Ouachita', 9, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (841, 'Chariton', 21, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (842, 'Kodiak Island', 14, '150', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (843, 'Eagle', 26, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (844, 'Fajardo', 39, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (845, 'Fulton', 4, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (846, 'Lee', 4, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (847, 'Dallas', 22, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (848, 'Jones', 25, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (849, 'Midland', 1, '329', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (850, 'Clark', 3, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (851, 'Wise', 7, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (852, 'Cooper', 21, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (853, 'Benton', 21, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (854, 'Madison', 1, '313', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (855, 'Milam', 1, '331', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (856, 'Sedgwick', 48, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (857, 'Lauderdale', 38, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (858, 'Ashley', 24, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (859, 'Modoc', 2, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (860, 'Richmond', 4, '245', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (861, 'Fremont', 22, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (862, 'Gallatin', 3, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (863, 'Carroll', 45, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (864, 'Miner', 23, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (865, 'Lac qui Parle', 16, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (866, 'Crittenden', 3, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (867, 'Madison', 27, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (868, 'Woods', 29, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (869, 'Jasper', 40, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (870, 'Rich', 28, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (871, 'Loudoun', 7, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (872, 'King George', 7, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (873, 'Clark', 12, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (874, 'Marshall', 32, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (875, 'Mercer', 51, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (876, 'Corson', 23, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (877, 'Clay', 8, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (878, 'Noble', 32, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (879, 'Clay', 3, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (880, 'Anson', 27, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (881, 'Madison', 20, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (882, 'Adair', 22, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (883, 'Wilson', 27, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (884, 'Meigs', 8, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (885, 'Preston', 31, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (886, 'Oneida', 5, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (887, 'Lake', 8, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (888, 'Saline', 20, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (889, 'Haakon', 23, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (890, 'Aguadilla', 39, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (891, 'Chester', 8, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (892, 'Greenup', 3, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (893, 'Linn', 48, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (894, 'Somerset', 45, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (895, 'Reno', 48, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (896, 'Hancock', 32, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (897, 'Will', 20, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (898, 'Pottawatomie', 48, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (899, 'Lemhi', 12, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (900, 'Rowan', 3, '205', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (901, 'Fulton', 3, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (902, 'De Soto', 9, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (903, 'Red River', 9, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (904, 'Floyd', 1, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (905, 'Collingsworth', 1, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (906, 'Pleasants', 31, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (907, 'Decatur', 48, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (908, 'Boundary', 12, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (909, 'Luna', 44, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (910, 'Warrick', 32, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (911, 'Hardin', 22, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (912, 'Wyandotte', 48, '209', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (913, 'Perkins', 23, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (914, 'Issaquena', 25, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (915, 'Rutherford', 8, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (916, 'Tippah', 25, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (917, 'Ballard', 3, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (918, 'Morgan', 21, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (919, 'Greene', 19, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (920, 'Camuy', 39, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (921, 'Castro', 1, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (922, 'Andrews', 1, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (923, 'Noble', 29, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (924, 'Lycoming', 47, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (925, 'Hill', 1, '217', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (926, 'Jersey', 20, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (927, 'Todd', 3, '219', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (928, 'Charlotte', 13, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (929, 'Dolores', 26, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (930, 'Elkhart', 32, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (931, 'Wood', 19, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (932, 'Nelson', 3, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (933, 'Yuma', 43, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (934, 'Pamlico', 27, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (935, 'Kewaunee', 5, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (936, 'Morgan', 8, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (937, 'Story', 22, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (938, 'Humacao', 39, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (939, 'Santa Cruz', 2, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (940, 'Amelia', 7, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (941, 'Sierra', 2, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (942, 'Mineral', 26, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (943, 'Carroll', 7, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (944, 'Jackson', 26, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (945, 'Houston', 38, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (946, 'Walton', 13, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (947, 'Wahkiakum', 18, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (948, 'Decatur', 4, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (949, 'Wilcox', 4, '315', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (950, 'Pike', 25, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (951, 'DeSoto', 25, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (952, 'Monroe', 31, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (953, 'Walworth', 23, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (954, 'Lawrence', 8, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (955, 'Menifee', 3, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (956, 'Ross', 19, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (957, 'Kemper', 25, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (958, 'Hale', 38, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (959, 'Butler', 21, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (960, 'Johnson', 22, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (961, 'Essex', 7, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (962, 'Jackson', 19, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (963, 'Ransom', 51, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (964, 'Union', 47, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (965, 'Rensselaer', 10, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (966, 'Gaston', 27, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (967, 'Venango', 47, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (968, 'Bullock', 38, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (969, 'Hall', 1, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (970, 'Allen', 48, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (971, 'Collin', 1, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (972, 'Culberson', 1, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (973, 'Comal', 1, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (974, 'Grayson', 7, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (975, 'Delaware', 22, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (976, 'Manatee', 13, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (977, 'Larimer', 26, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (978, 'Leon', 1, '289', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (979, 'Hamilton', 22, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (980, 'Burke', 4, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (981, 'Morrow', 19, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (982, 'Harrison', 25, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (983, 'Isabela', 39, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (984, 'Las Piedras', 39, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (985, 'Otter Tail', 16, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (986, 'Itawamba', 25, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (987, 'Hart', 4, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (988, 'Smith', 48, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (989, 'Grand Traverse', 11, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (990, 'Salinas', 39, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (991, 'Harrison', 22, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (992, 'Morgan', 3, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (993, 'St. Helena', 9, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (994, 'Haywood', 27, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (995, 'Darlington', 40, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (996, 'Glacier', 15, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (997, 'Mercer', 19, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (998, 'Hendry', 13, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (999, 'Dorado', 39, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1000, 'Erath', 1, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1001, 'Moultrie', 20, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1002, 'Coffey', 48, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1003, 'Coles', 20, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1004, 'Jackson', 3, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1005, 'Franklin', 27, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1006, 'Decatur', 22, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1007, 'Shelby', 8, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1008, 'Grant', 16, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1009, 'Delta', 1, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1010, 'Henry', 4, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1011, 'Menard', 20, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1012, 'Muskingum', 19, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1013, 'Noble', 19, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1014, 'Prowers', 26, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1015, 'Granville', 27, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1016, 'Randolph', 20, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1017, 'Chatham', 4, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1018, 'Linn', 22, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1019, 'Hudspeth', 1, '229', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1020, 'Henry', 32, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1021, 'Warren', 3, '227', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1022, 'Caddo', 29, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1023, 'Houston', 1, '225', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1024, 'Parmer', 1, '369', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1025, 'Pennington', 23, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1026, 'Campbell', 23, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1027, 'Lake', 13, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1028, 'Clatsop', 6, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1029, 'Tompkins', 10, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1030, 'Wapello', 22, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1031, 'Gasconade', 21, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1032, 'Sweet Grass', 15, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1033, 'LaMoure', 51, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1034, 'Faulkner', 24, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1035, 'Wilson', 48, '205', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1036, 'Iron', 11, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1037, 'Jackson', 11, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1038, 'Chatham', 27, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1039, 'Medina', 1, '325', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1040, 'Utah', 28, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1041, 'Wilkes', 27, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1042, 'Marshall', 23, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1043, 'Presidio', 1, '377', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1044, 'San Juan', 26, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1045, 'Plymouth', 22, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1046, 'Tazewell', 20, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1047, 'Dodge', 4, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1048, 'Montrose', 26, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1049, 'Sherman', 1, '421', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1050, 'Starr', 1, '427', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1051, 'Lincoln', 21, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1052, 'Butler', 17, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1053, 'Vermilion', 20, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1054, 'Benzie', 11, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1055, 'Lafourche', 9, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1056, 'DeKalb', 20, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1057, 'Muhlenberg', 3, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1058, 'Montgomery', 10, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1059, 'Livingston', 11, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1060, 'Coal', 29, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1061, 'Flagler', 13, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1062, 'Payne', 29, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1063, 'Defiance', 19, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1064, 'Cass', 32, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1065, 'Riley', 48, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1066, 'Burnett', 5, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1067, 'Chisago', 16, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1068, 'Nicholas', 3, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1069, 'Moore', 27, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1070, 'Gallatin', 20, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1071, 'Greene', 20, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1072, 'Big Stone', 16, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1073, 'Roscommon', 11, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1074, 'Panola', 1, '365', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1075, 'Boone', 20, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1076, 'Terrell', 1, '443', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1077, 'Keokuk', 22, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1078, 'Hardee', 13, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1079, 'Woodford', 20, '203', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1080, 'Union', 19, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1081, 'Vinton', 19, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1082, 'Auglaize', 19, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1083, 'Hillsborough', 13, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1084, 'Luzerne', 47, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1085, 'Morgan', 31, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1086, 'Grenada', 25, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1087, 'Winston', 25, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1088, 'DeKalb', 21, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1089, 'Radford', 7, '750', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1090, 'Augusta', 7, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1091, 'Franklin', 17, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1092, 'Floyd', 3, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1093, 'Schoharie', 10, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1094, 'Waldo', 41, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1095, 'Chilton', 38, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1096, 'Harrison', 3, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1097, 'Sullivan', 47, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1098, 'Bradford', 13, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1099, 'Wolfe', 3, '237', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1100, 'Davidson', 27, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1101, 'Garfield', 29, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1102, 'Abbeville', 40, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1103, 'Breckinridge', 3, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1104, 'Gibson', 8, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1105, 'Obion', 8, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1106, 'Caldwell', 3, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1107, 'Wharton', 1, '481', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1108, 'Guernsey', 19, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1109, 'Hocking', 19, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1110, 'Randolph', 4, '243', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1111, 'Pottawattamie', 22, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1112, 'Tattnall', 4, '267', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1113, 'McDowell', 31, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1114, 'Harrisonburg', 7, '660', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1115, 'Hampshire', 31, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1116, 'Oktibbeha', 25, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1117, 'Giles', 7, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1118, 'Columbia', 13, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1119, 'Barranquitas', 39, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1120, 'Fayette', 31, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1121, 'Florida', 39, '054', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1122, 'Baca', 26, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1123, 'Athens', 19, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1124, 'Bandera', 1, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1125, 'Harper', 29, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1126, 'Harding', 23, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1127, 'Pierce', 5, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1128, 'McCulloch', 1, '307', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1129, 'Cochise', 43, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1130, 'Clarke', 25, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1131, 'Bamberg', 40, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1132, 'Carter', 8, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1133, 'Cheatham', 8, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1134, 'Cocke', 8, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1135, 'Austin', 1, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1136, 'Cameron', 47, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1137, 'Cherokee', 40, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1138, 'Custer', 23, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1139, 'Towns', 4, '281', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1140, 'Queen Anne''s', 45, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1141, 'Vermilion', 9, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1142, 'Vanderburgh', 32, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1143, 'Henderson', 3, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1144, 'Lake', 16, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1145, 'Schleicher', 1, '413', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1146, 'Hancock', 25, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1147, 'Cheyenne', 26, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1148, 'Van Buren', 22, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1149, 'Franklin', 22, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1150, 'Cleburne', 38, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1151, 'St. Louis', 21, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1152, 'Virginia Beach', 7, '810', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1153, 'Olmsted', 16, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1154, 'Cass', 21, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1155, 'Judith Basin', 15, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1156, 'Price', 5, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1157, 'Unicoi', 8, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1158, 'Washington', 8, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1159, 'Brooks', 1, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1160, 'Williamson', 8, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1161, 'Johnson', 30, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1162, 'Pickens', 40, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1163, 'Clarendon', 40, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1164, 'Sullivan', 8, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1165, 'Hanson', 23, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1166, 'Chester', 47, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1167, 'Houston', 8, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1168, 'Minnehaha', 23, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1169, 'Tillamook', 6, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1170, 'Barbour', 31, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1171, 'San Patricio', 1, '409', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1172, 'Stevens', 16, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1173, 'Kings', 2, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1174, 'Jefferson', 19, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1175, 'Martin', 27, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1176, 'Adams', 19, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1177, 'Douglas', 48, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1178, 'Wright', 16, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1179, 'Saunders', 17, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1180, 'Lee', 22, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1181, 'Jasper', 20, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1182, 'Bay', 11, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1183, 'Ponce', 39, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1184, 'Shiawassee', 11, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1185, 'Grant', 51, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1186, 'Douglas', 34, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1187, 'Scott', 22, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1188, 'Newberry', 40, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1189, 'Union', 40, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1190, 'Newport', 37, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1191, 'Franklin', 33, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1192, 'LaGrange', 32, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1193, 'Wayne', 28, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1194, 'Silver Bow', 15, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1195, 'Union', 13, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1196, 'Addison', 49, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1197, 'Le Sueur', 16, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1198, 'Carbon', 30, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1199, 'Lyon', 16, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1200, 'Hampton', 40, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1201, 'Perry', 8, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1202, 'Sheridan', 51, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1203, 'Howard', 24, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1204, 'Stearns', 16, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1205, 'Humboldt', 2, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1206, 'Middlesex', 50, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1207, 'Broadwater', 15, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1208, 'Ottawa', 29, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1209, 'Jones', 4, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1210, 'Gwinnett', 4, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1211, 'Jefferson', 48, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1212, 'Iron', 5, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1213, 'Tama', 22, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1214, 'Tehama', 2, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1215, 'Mono', 2, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1216, 'Boone', 22, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1217, 'Putnam', 32, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1218, 'Linn', 6, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1219, 'Scott', 21, '201', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1220, 'Essex', 49, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1221, 'Goodhue', 16, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1222, 'Walla Walla', 18, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1223, 'Miller', 21, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1224, 'Jackson', 24, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1225, 'Forsyth', 27, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1226, 'Cedar', 17, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1227, 'Kiowa', 26, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1228, 'Pulaski', 24, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1229, 'Bedford', 47, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1230, 'Shelby', 21, '205', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1231, 'Adams', 5, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1232, 'Pike', 21, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1233, 'Sherman', 6, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1234, 'Umatilla', 6, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1235, 'Forest', 5, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1236, 'Sauk', 5, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1237, 'Lee', 24, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1238, 'Prairie', 24, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1239, 'Jackson', 5, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1240, 'Carroll', 52, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1241, 'Page', 22, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1242, 'Kershaw', 40, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1243, 'Power', 12, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1244, 'Nevada', 2, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1245, 'Shelby', 1, '419', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1246, 'Custer', 15, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1247, 'Nelson', 7, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1248, 'Stutsman', 51, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1249, 'Josephine', 6, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1250, 'Cass', 20, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1251, 'Franklin', 47, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1252, 'Finney', 48, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1253, 'Nottoway', 7, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1254, 'Freestone', 1, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1255, 'Fulton', 32, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1256, 'Phillips', 15, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1257, 'Carbon', 28, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1258, 'Grand', 28, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1259, 'Millard', 28, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1260, 'St. Johns', 13, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1261, 'Assumption', 9, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1262, 'Macon', 4, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1263, 'Gordon', 4, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1264, 'Jefferson', 12, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1265, 'Madison', 3, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1266, 'Lincoln', 12, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1267, 'Kenai Peninsula', 14, '122', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1268, 'Whatcom', 18, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1269, 'Moore', 1, '341', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1270, 'Caledonia', 49, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1271, 'Oregon', 21, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1272, 'Island', 18, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1273, 'Hudson', 50, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1274, 'Howell', 21, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1275, 'Lake and Peninsula', 14, '164', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1276, 'Nez Perce', 12, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1277, 'Candler', 4, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1278, 'Lake of the Woods', 16, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1279, 'Storey', 34, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1280, 'Gonzales', 1, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1281, 'Cabo Rojo', 39, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1282, 'Lake', 32, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1283, 'Lehigh', 47, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1284, 'Ripley', 21, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1285, 'Lincoln', 18, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1286, 'Skagit', 18, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1287, 'Washington', 16, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1288, 'Thurston', 18, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1289, 'Camp', 1, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1290, 'Lorain', 19, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1291, 'Gilchrist', 13, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1292, 'Scott', 16, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1293, 'Lafayette', 13, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1294, 'Tallahatchie', 25, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1295, 'Vega Baja', 39, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1296, 'Sonoma', 2, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1297, 'Allamakee', 22, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1298, 'Clayton', 22, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1299, 'Jackson', 9, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1300, 'Del Norte', 2, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1301, 'Pasquotank', 27, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1302, 'Kimble', 1, '267', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1303, 'Mifflin', 47, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1304, 'Macon', 21, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1305, 'Montgomery', 47, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1306, 'Hitchcock', 17, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1307, 'Union', 9, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1308, 'Bronx', 10, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1309, 'Brevard', 13, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1310, 'Racine', 5, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1311, 'Chittenden', 49, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1312, 'Pershing', 34, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1313, 'Franklin', 7, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1314, 'Green', 5, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1315, 'Vega Alta', 39, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1316, 'Roberts', 23, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1317, 'Daviess', 21, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1318, 'Grundy', 21, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1319, 'Franklin', 10, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1320, 'Moore', 8, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1321, 'Marshall', 38, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1322, 'Brazos', 1, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1323, 'Antelope', 17, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1324, 'Fauquier', 7, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1325, 'Hampton', 7, '650', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1326, 'Douglas', 21, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1327, 'Baxter', 24, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1328, 'Madison', 9, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1329, 'Broomfield', 26, '014', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1330, 'Morris', 50, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1331, 'Boulder', 26, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1332, 'Brazoria', 1, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1333, 'Green Lake', 5, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1334, 'Champaign', 19, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1335, 'Perry', 47, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1336, 'Cedar', 22, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1337, 'Doña Ana', 44, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1338, 'Ashe', 27, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1339, 'Russell', 7, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1340, 'Ellis', 1, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1341, 'Caribou', 12, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1342, 'Montgomery', 20, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1343, 'Kauai', 42, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1344, 'Meade', 23, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1345, 'Halifax', 27, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1346, 'Clearwater', 16, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1347, 'Orange', 7, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1348, 'Walker', 1, '471', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1349, 'Cumberland', 8, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1350, 'Jefferson', 38, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1351, 'Marshall', 29, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1352, 'Pittsburg', 29, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1353, 'Tuscaloosa', 38, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1354, 'Cherokee', 27, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1355, 'Dent', 21, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1356, 'Crowley', 26, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1357, 'Jefferson', 29, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1358, 'Tillman', 29, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1359, 'Gilpin', 26, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1360, 'St. Francois', 21, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1361, 'Las Animas', 26, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1362, 'Coos', 52, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1363, 'Cabarrus', 27, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1364, 'Buncombe', 27, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1365, 'Fannin', 1, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1366, 'Chaves', 44, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1367, 'Knox', 19, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1368, 'Fergus', 15, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1369, 'Crow Wing', 16, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1370, 'Williams', 19, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1371, 'Natchitoches', 9, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1372, 'Clay', 27, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1373, 'Philadelphia', 47, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1374, 'Marion', 8, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1375, 'Aitkin', 16, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1376, 'Washita', 29, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1377, 'Autauga', 38, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1378, 'Ascension', 9, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1379, 'Clarke', 38, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1380, 'Monroe', 19, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1381, 'Monroe', 38, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1382, 'Allegany', 45, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1383, 'Sumter', 38, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1384, 'Walker', 38, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1385, 'Mackinac', 11, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1386, 'Taylor', 1, '441', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1387, 'Sanders', 15, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1388, 'St. Charles', 9, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1389, 'Grady', 29, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1390, 'McDowell', 27, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1391, 'Spotsylvania', 7, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1392, 'Merrimack', 52, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1393, 'Union', 44, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1394, 'Banner', 17, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1395, 'Wayne', 27, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1396, 'Cleveland', 27, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1397, 'Gilliam', 6, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1398, 'Ramsey', 51, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1399, 'Ada', 12, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1400, 'Indian River', 13, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1401, 'Grand', 26, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1402, 'Lucas', 19, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1403, 'Lawrence', 38, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1404, 'Chelan', 18, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1405, 'Holmes', 13, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1406, 'Jefferson', 13, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1407, 'Okaloosa', 13, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1408, 'Columbia', 6, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1409, 'Crawford', 24, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1410, 'Harrison', 1, '203', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1411, 'Otsego', 10, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1412, 'Madison', 24, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1413, 'Wood', 1, '499', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1414, 'Bryan', 29, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1415, 'Henry', 22, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1416, 'Holt', 17, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1417, 'Juniata', 47, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1418, 'Clay', 20, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1419, 'Knox', 21, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1420, 'Maries', 21, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1421, 'Mississippi', 21, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1422, 'Bradley', 24, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1423, 'Madison', 17, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1424, 'Clay', 24, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1425, 'Webster', 3, '233', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1426, 'Jayuya', 39, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1427, 'Fayette', 1, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1428, 'Bon Homme', 23, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1429, 'Chesterfield', 40, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1430, 'Kimball', 17, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1431, 'Independence', 24, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1432, 'Bexar', 1, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1433, 'Chase', 17, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1434, 'Dewey', 23, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1435, 'Allegan', 11, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1436, 'Stanly', 27, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1437, 'Lexington', 40, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1438, 'Teton', 30, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1439, 'Hampden', 33, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1440, 'Sheridan', 48, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1441, 'Webster', 25, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1442, 'McPherson', 17, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1443, 'Sandoval', 44, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1444, 'Davidson', 8, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1445, 'Clark', 5, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1446, 'Martin', 1, '317', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1447, 'Manatí', 39, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1448, 'Johnson', 32, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1449, 'Cochran', 1, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1450, 'Fairfield', 19, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1451, 'Langlade', 5, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1452, 'Isabella', 11, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1453, 'Burke', 27, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1454, 'Grand Forks', 51, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1455, 'San Juan', 18, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1456, 'Brown', 5, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1457, 'Telfair', 4, '271', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1458, 'Ware', 4, '299', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1459, 'Rice', 48, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1460, 'Clare', 11, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1461, 'Hancock', 4, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1462, 'Drew', 24, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1463, 'Crawford', 21, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1464, 'Greeley', 48, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1465, 'Northumberland', 7, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1466, 'Haywood', 8, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1467, 'Patrick', 7, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1468, 'Laclede', 21, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1469, 'Gloucester', 50, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1470, 'McIntosh', 51, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1471, 'Ciales', 39, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1472, 'Sullivan', 52, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1473, 'Saline', 21, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1474, 'Montgomery', 19, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1475, 'Acadia', 9, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1476, 'Wayne', 32, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1477, 'Atchison', 21, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1478, 'Harmon', 29, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1479, 'York', 7, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1480, 'Pulaski', 4, '235', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1481, 'Greenwood', 48, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1482, 'Missaukee', 11, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1483, 'Androscoggin', 41, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1484, 'Dickinson', 22, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1485, 'Dickinson', 11, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1486, 'Marion', 48, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1487, 'Cowley', 48, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1488, 'Logan', 3, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1489, 'Weber', 28, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1490, 'Kandiyohi', 16, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1491, 'Montgomery', 27, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1492, 'Braxton', 31, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1493, 'Marion', 25, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1494, 'Naguabo', 39, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1495, 'Beaver', 28, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1496, 'Bingham', 12, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1497, 'Claiborne', 9, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1498, 'Schoolcraft', 11, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1499, 'Chase', 48, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1500, 'Crosby', 1, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1501, 'Perkins', 17, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1502, 'Garrett', 45, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1503, 'Lipscomb', 1, '295', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1504, 'Jefferson', 21, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1505, 'Cass', 17, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1506, 'Washington', 21, '221', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1507, 'Haskell', 48, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1508, 'Creek', 29, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1509, 'Oglala Lakota', 23, '102', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1510, 'Gurabo', 39, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1511, 'Henderson', 20, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1512, 'Mills', 22, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1513, 'Wright', 21, '229', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1514, 'Alfalfa', 29, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1515, 'Montcalm', 11, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1516, 'Delaware', 47, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1517, 'Cortland', 10, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1518, 'Columbia', 47, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1519, 'Charlottesville', 7, '540', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1520, 'Appomattox', 7, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1521, 'Davie', 27, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1522, 'Buena Vista', 7, '530', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1523, 'Guilford', 27, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1524, 'Taylor', 4, '269', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1525, 'Iron', 21, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1526, 'Coos', 6, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1527, 'Oconee', 40, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1528, 'Gage', 17, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1529, 'Stone', 21, '209', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1530, 'Aransas', 1, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1531, 'Anchorage', 14, '020', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1532, 'Edwards', 48, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1533, 'Fentress', 8, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1534, 'Rockdale', 4, '247', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1535, 'Ottawa', 48, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1536, 'Bracken', 3, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1537, 'Mora', 44, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1538, 'Lake', 11, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1539, 'Clarion', 47, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1540, 'Madison', 7, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1541, 'Broward', 13, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1542, 'Freeborn', 16, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1543, 'Alcona', 11, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1544, 'Allegany', 10, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1545, 'Hood River', 6, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1546, 'Lawrence', 24, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1547, 'Buchanan', 22, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1548, 'Forrest', 25, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1549, 'Warren', 22, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1550, 'Powell', 3, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1551, 'Effingham', 20, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1552, 'Hamilton', 20, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1553, 'Bourbon', 3, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1554, 'Blair', 47, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1555, 'Lincoln', 23, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1556, 'Barnwell', 40, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1557, 'Dickson', 8, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1558, 'Hamlin', 23, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1559, 'Currituck', 27, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1560, 'Audubon', 22, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1561, 'Benton', 8, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1562, 'Vernon', 9, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1563, 'Bath', 3, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1564, 'Jefferson', 6, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1565, 'Adjuntas', 39, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1566, 'Pike', 20, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1567, 'Texas', 29, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1568, 'Yates', 10, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1569, 'Kitsap', 18, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1570, 'Cole', 21, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1571, 'Wirt', 31, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1572, 'Winnebago', 22, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1573, 'Walker', 4, '295', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1574, 'Orange', 27, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1575, 'Berks', 47, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1576, 'Frio', 1, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1577, 'Monongalia', 31, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1578, 'Juncos', 39, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1579, 'Greene', 32, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1580, 'Brown', 19, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1581, 'Poquoson', 7, '735', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1582, 'Ziebach', 23, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1583, 'Horry', 40, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1584, 'Daviess', 32, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1585, 'Calhoun', 22, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1586, 'Fremont', 12, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1587, 'Curry', 44, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1588, 'Summers', 31, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1589, 'Fountain', 32, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1590, 'Norton', 7, '720', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1591, 'Clay', 16, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1592, 'Kern', 2, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1593, 'Brown', 32, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1594, 'Logan', 29, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1595, 'Craig', 29, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1596, 'Danville', 7, '590', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1597, 'Cibola', 44, '006', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1598, 'Jefferson', 3, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1599, 'Lancaster', 40, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1600, 'Sussex', 7, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1601, 'Añasco', 39, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1602, 'Bucks', 47, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1603, 'Tipton', 8, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1604, 'Las Marías', 39, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1605, 'Donley', 1, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1606, 'Murray', 4, '213', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1607, 'Jewell', 48, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1608, 'Wilkinson', 25, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1609, 'Onslow', 27, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1610, 'Goshen', 30, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1611, 'Webster', 4, '307', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1612, 'Oakland', 11, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1613, 'Becker', 16, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1614, 'Russell', 48, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1615, 'Casey', 3, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1616, 'Dixon', 17, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1617, 'Prince George', 7, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1618, 'Albany', 30, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1619, 'Franklin', 21, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1620, 'Alexandria', 7, '510', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1621, 'Ontario', 10, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1622, 'Peñuelas', 39, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1623, 'Okeechobee', 13, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1624, 'Pecos', 1, '371', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1625, 'Effingham', 4, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1626, 'Houston', 4, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1627, 'Screven', 4, '251', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1628, 'Alpine', 2, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1629, 'Wayne', 10, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1630, 'Greenville', 40, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1631, 'Uvalde', 1, '463', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1632, 'Menominee', 5, '078', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1633, 'Starke', 32, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1634, 'Calhoun', 13, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1635, 'Estill', 3, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1636, 'Dawson', 17, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1637, 'Petroleum', 15, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1638, 'Upton', 1, '461', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1639, 'Wise', 1, '497', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1640, 'Hood', 1, '221', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1641, 'Conecuh', 38, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1642, 'Allen', 32, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1643, 'Morton', 48, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1644, 'Seward', 17, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1645, 'Kent', 45, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1646, 'Albany', 10, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1647, 'Plymouth', 33, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1648, 'Niagara', 10, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1649, 'Clark', 18, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1650, 'Elmore', 12, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1651, 'Van Zandt', 1, '467', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1652, 'Barron', 5, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1653, 'Hampshire', 33, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1654, 'Walton', 4, '297', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1655, 'McDuffie', 4, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1656, 'Milwaukee', 5, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1657, 'Crawford', 47, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1658, 'Branch', 11, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1659, 'Henry', 19, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1660, 'Alcorn', 25, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1661, 'Pontotoc', 29, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1662, 'Yavapai', 43, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1663, 'Durham', 27, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1664, 'Arlington', 7, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1665, 'Caldwell', 1, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1666, 'Norfolk', 33, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1667, 'Lancaster', 47, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1668, 'Randolph', 38, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1669, 'Louisa', 22, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1670, 'Berrien', 11, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1671, 'Cumberland', 3, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1672, 'Shenandoah', 7, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1673, 'Teller', 26, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1674, 'Todd', 16, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1675, 'Owen', 3, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1676, 'Anoka', 16, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1677, 'Republic', 48, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1678, 'Rockcastle', 3, '203', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1679, 'De Baca', 44, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1680, 'San Sebastián', 39, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1681, 'Collier', 13, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1682, 'West Carroll', 9, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1683, 'Potter', 47, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1684, 'Hardeman', 1, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1685, 'Mason', 31, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1686, 'Buchanan', 7, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1687, 'Lancaster', 17, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1688, 'Volusia', 13, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1689, 'Clarke', 22, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1690, 'Jones', 22, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1691, 'Claiborne', 25, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1692, 'Wythe', 7, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1693, 'Cherokee', 38, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1694, 'Prince George''s', 45, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1695, 'Granite', 15, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1696, 'Audrain', 21, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1697, 'Monmouth', 50, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1698, 'Warren', 47, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1699, 'Chippewa', 16, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1700, 'Edwards', 20, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1701, 'Aurora', 23, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1702, 'Carlisle', 3, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1703, 'Licking', 19, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1704, 'Waynesboro', 7, '820', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1705, 'Baylor', 1, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1706, 'Gray', 48, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1707, 'Cherokee', 4, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1708, 'Greene', 22, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1709, 'Hamilton', 8, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1710, 'Charles', 45, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1711, 'Glynn', 4, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1712, 'Suffolk', 33, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1713, 'Jefferson', 5, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1714, 'Luquillo', 39, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1715, 'Nobles', 16, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1716, 'Phelps', 21, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1717, 'Habersham', 4, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1718, 'Switzerland', 32, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1719, 'Johnson', 3, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1720, 'Burke', 51, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1721, 'Miami', 32, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1722, 'Pontotoc', 25, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1723, 'Dauphin', 47, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1724, 'Adams', 18, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1725, 'Yuma', 26, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1726, 'Marquette', 11, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1727, 'Richmond City', 7, '760', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1728, 'Sumter', 13, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1729, 'Blue Earth', 16, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1730, 'Union', 23, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1731, 'Edgefield', 40, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1732, 'Hickman', 8, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1733, 'San Augustine', 1, '405', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1734, 'Calhoun', 11, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1735, 'Coahoma', 25, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1736, 'Mahoning', 19, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1737, 'Carroll', 8, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1738, 'Dorchester', 45, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1739, 'Lawrence', 47, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1740, 'Covington', 7, '580', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1741, 'Vernon', 5, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1742, 'Hempstead', 24, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1743, 'Owen', 32, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1744, 'Mahaska', 22, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1745, 'Edmonson', 3, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1746, 'Valley', 17, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1747, 'Stark', 19, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1748, 'Susquehanna', 47, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1749, 'Northampton', 7, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1750, 'Oglethorpe', 4, '221', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1751, 'Sharkey', 25, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1752, 'Medina', 19, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1753, 'Aguada', 39, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1754, 'Tuolumne', 2, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1755, 'Prairie', 15, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1756, 'Fluvanna', 7, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1757, 'Crook', 30, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1758, 'Marion', 21, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1759, 'San Miguel', 26, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1760, 'Red Willow', 17, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1761, 'Lamar', 1, '277', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1762, 'Troup', 4, '285', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1763, 'Real', 1, '385', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1764, 'Sioux', 22, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1765, 'Travis', 1, '453', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1766, 'Taliaferro', 4, '265', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1767, 'Twiggs', 4, '289', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1768, 'Roger Mills', 29, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1769, 'San Juan', 39, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1770, 'Jackson', 22, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1771, 'Lamar', 25, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1772, 'Rains', 1, '379', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1773, 'Washington', 24, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1774, 'Sherman', 48, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1775, 'Neosho', 48, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1776, 'Jackson', 25, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1777, 'Wilson', 1, '493', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1778, 'Hooker', 17, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1779, 'Hardin', 1, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1780, 'Columbia', 24, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1781, 'Heard', 4, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1782, 'Adams', 32, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1783, 'Gladwin', 11, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1784, 'Boone', 3, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1785, 'Leelanau', 11, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1786, 'Park', 15, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1787, 'Webster', 31, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1788, 'Nowata', 29, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1789, 'Armstrong', 1, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1790, 'Hernando', 13, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1791, 'Mitchell', 22, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1792, 'Webster', 17, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1793, 'Loving', 1, '301', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1794, 'Washington', 3, '229', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1795, 'Robertson', 1, '395', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1796, 'Ness', 48, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1797, 'Jefferson', 4, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1798, 'Pine', 16, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1799, 'Gadsden', 13, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1800, 'Mercer', 31, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1801, 'Vieques', 39, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1802, 'Nance', 17, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1803, 'DeSoto', 13, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1804, 'Hardy', 31, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1805, 'Thayer', 17, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1806, 'Frontier', 17, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1807, 'Lowndes', 38, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1808, 'Talbot', 4, '263', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1809, 'Peoria', 20, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1810, 'Logan', 48, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1811, 'Johnston', 27, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1812, 'Mason', 1, '319', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1813, 'Piute', 28, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1814, 'Calhoun', 31, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1815, 'Jackson', 29, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1816, 'Greene', 38, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1817, 'Searcy', 24, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1818, 'Seminole', 13, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1819, 'Hutchinson', 1, '233', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1820, 'McCone', 15, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1821, 'Franklin', 9, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1822, 'St. Francis', 24, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1823, 'Ralls', 21, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1824, 'Furnas', 17, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1825, 'Beaver', 29, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1826, 'Blount', 38, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1827, 'Dinwiddie', 7, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1828, 'Maunabo', 39, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1829, 'Grayson', 1, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1830, 'St. Clair', 11, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1831, 'Ochiltree', 1, '357', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1832, 'Shawnee', 48, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1833, 'Des Moines', 22, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1834, 'Gates', 27, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1835, 'Fairfax City', 7, '600', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1836, 'Comanche', 29, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1837, 'Stephens', 29, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1838, 'Box Butte', 17, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1839, 'Decatur', 32, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1840, 'Monroe', 22, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1841, 'Sampson', 27, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1842, 'Leflore', 25, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1843, 'Henderson', 1, '213', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1844, 'Prince Edward', 7, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1845, 'Jasper', 32, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1846, 'Sevier', 28, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1847, 'Washakie', 30, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1848, 'Crawford', 5, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1849, 'Merced', 2, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1850, 'Scotland', 27, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1851, 'Watauga', 27, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1852, 'New Kent', 7, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1853, 'Carroll', 24, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1854, 'Crawford', 20, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1855, 'Bottineau', 51, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1856, 'Ouachita', 24, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1857, 'Tyrrell', 27, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1858, 'Hawkins', 8, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1859, 'Gilmer', 4, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1860, 'Hale', 1, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1861, 'Monroe', 47, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1862, 'Massac', 20, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1863, 'Costilla', 26, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1864, 'Payette', 12, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1865, 'Toole', 15, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1866, 'Gregory', 23, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1867, 'Bibb', 38, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1868, 'Lee', 25, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1869, 'Alexander', 20, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1870, 'Wilson', 8, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1871, 'Crawford', 32, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1872, 'Wagoner', 29, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1873, 'Bienville', 9, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1874, 'Sangamon', 20, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1875, 'Graves', 3, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1876, 'Sebastian', 24, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1877, 'Webster', 21, '225', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1878, 'Edwards', 1, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1879, 'Greene', 21, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1880, 'Scott', 48, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1881, 'Franklin', 3, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1882, 'Calaveras', 2, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1883, 'Custer', 17, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1884, 'Mathews', 7, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1885, 'Christian', 20, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1886, 'Anderson', 1, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1887, 'Southampton', 7, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1888, 'Charlotte', 7, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1889, 'Tripp', 23, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1890, 'King and Queen', 7, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1891, 'San Joaquin', 2, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1892, 'Eaton', 11, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1893, 'Sanpete', 28, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1894, 'Washburn', 5, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1895, 'Lanier', 4, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1896, 'Iberville', 9, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1897, 'Onondaga', 10, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1898, 'Armstrong', 47, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1899, 'Middlesex', 7, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1900, 'Wayne', 20, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1901, 'Williamson', 1, '491', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1902, 'Kanawha', 31, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1903, 'Poinsett', 24, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1904, 'Jones', 23, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1905, 'Cecil', 45, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1906, 'Mercer', 20, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1907, 'Stanislaus', 2, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1908, 'Webster', 9, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1909, 'Randolph', 27, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1910, 'Wallace', 48, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1911, 'Noxubee', 25, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1912, 'Dunn', 5, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1913, 'McCurtain', 29, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1914, 'Pawnee', 17, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1915, 'Buena Vista', 22, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1916, 'Caroline', 45, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1917, 'DeKalb', 4, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1918, 'Kalamazoo', 11, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1919, 'Martin', 3, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1920, 'Hoke', 27, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1921, 'Mitchell', 27, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1922, 'Brunswick', 27, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1923, 'Red River', 1, '387', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1924, 'Black Hawk', 22, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1925, 'Jasper', 22, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1926, 'Jefferson', 22, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1927, 'Porter', 32, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1928, 'Cass', 1, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1929, 'Bossier', 9, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1930, 'McLennan', 1, '309', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1931, 'Cuming', 17, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1932, 'Guadalupe', 44, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1933, 'Camden', 4, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1934, 'Clay', 23, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1935, 'Etowah', 38, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1936, 'Tift', 4, '277', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1937, 'Sumter', 4, '261', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1938, 'Natrona', 30, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1939, 'Columbia', 18, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1940, 'Burnet', 1, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1941, 'Hancock', 31, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1942, 'Fort Bend', 1, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1943, 'Ford', 48, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1944, 'Jackson', 20, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1945, 'Catawba', 27, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1946, 'DeKalb', 38, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1947, 'McLean', 51, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1948, 'Richland', 40, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1949, 'Dickey', 51, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1950, 'Haskell', 1, '207', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1951, 'Portsmouth', 7, '740', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1952, 'Clay', 31, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1953, 'Calhoun', 38, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1954, 'Coamo', 39, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1955, 'Covington', 38, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1956, 'Baltimore', 45, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1957, 'Dundy', 17, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1958, 'Pope', 20, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1959, 'Ste. Genevieve', 21, '186', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1960, 'Edgar', 20, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1961, 'Beaufort', 40, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1962, 'Hinds', 25, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1963, 'Dawson', 15, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1964, 'Montague', 1, '337', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1965, 'Butler', 47, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1966, 'Emery', 28, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1967, 'Juab', 28, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1968, 'Calhoun', 1, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1969, 'Iowa', 5, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1970, 'Oneida', 12, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1971, 'McPherson', 48, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1972, 'Sutter', 2, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1973, 'Wyoming', 47, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1974, 'Larue', 3, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1975, 'Chicot', 24, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1976, 'Ventura', 2, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1977, 'Clay', 4, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1978, 'Lincoln', 4, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1979, 'Calhoun', 20, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1980, 'Lucas', 22, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1981, 'Grant', 24, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1982, 'Dade', 21, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1983, 'Johnson', 1, '251', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1984, 'Knox', 1, '275', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1985, 'Ashland', 5, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1986, 'Charleston', 40, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1987, 'Decatur', 8, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1988, 'Hamblen', 8, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1989, 'Sanilac', 11, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1990, 'Matagorda', 1, '321', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1991, 'Cleveland', 24, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1992, 'Wasatch', 28, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1993, 'Shasta', 2, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1994, 'Burt', 17, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1995, 'Camden', 21, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1996, 'Pittsylvania', 7, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1997, 'Carter', 15, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1998, 'Santa Barbara', 2, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (1999, 'Riverside', 2, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2000, 'Colleton', 40, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2001, 'Mobile', 38, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2002, 'Escambia', 38, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2003, 'Carroll', 25, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2004, 'Lamar', 4, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2005, 'Morton', 51, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2006, 'San Juan', 28, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2007, 'La Crosse', 5, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2008, 'Huntingdon', 47, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2009, 'Boise', 12, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2010, 'Adams', 12, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2011, 'Routt', 26, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2012, 'Craven', 27, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2013, 'Ocean', 50, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2014, 'Polk', 24, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2015, 'Catahoula', 9, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2016, 'Concordia', 9, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2017, 'Jackson', 23, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2018, 'Solano', 2, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2019, 'James City', 7, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2020, 'Washington', 27, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2021, 'Kent', 11, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2022, 'Essex', 50, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2023, 'Burlington', 50, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2024, 'Clackamas', 6, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2025, 'Clay', 25, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2026, 'Grundy', 22, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2027, 'Delta', 26, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2028, 'Saline', 48, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2029, 'Woodbury', 22, '193', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2030, 'Bibb', 4, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2031, 'Dallas', 1, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2032, 'McCook', 23, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2033, 'Wayne', 11, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2034, 'Meagher', 15, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2035, 'Cumberland', 7, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2036, 'Borden', 1, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2037, 'Brewster', 1, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2038, 'Alachua', 13, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2039, 'Mercer', 47, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2040, 'Livingston', 21, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2041, 'Orangeburg', 40, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2042, 'Cherokee', 1, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2043, 'Kerr', 1, '265', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2044, 'Snohomish', 18, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2045, 'Jefferson', 8, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2046, 'Cleveland', 29, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2047, 'La Paz', 43, '012', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2048, 'Bell', 3, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2049, 'Washington', 6, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2050, 'Williams', 51, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2051, 'Benton', 6, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2052, 'Rockingham', 52, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2053, 'Cumberland', 50, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2054, 'Salem', 50, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2055, 'Dare', 27, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2056, 'Sheboygan', 5, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2057, 'Fairfax', 7, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2058, 'Henderson', 8, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2059, 'Jasper', 1, '241', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2060, 'Clinton', 47, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2061, 'Okanogan', 18, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2062, 'Stevens', 18, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2063, 'Whitfield', 4, '313', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2064, 'Nueces', 1, '355', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2065, 'Orleans', 49, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2066, 'Baldwin', 38, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2067, 'Monroe', 8, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2068, 'Coryell', 1, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2069, 'Le Flore', 29, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2070, 'Cumberland', 47, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2071, 'Roberts', 1, '393', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2072, 'Sagadahoc', 41, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2073, 'Jerome', 12, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2074, 'New London', 35, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2075, 'Bryan', 4, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2076, 'Bear Lake', 12, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2077, 'Mesa', 26, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2078, 'Callaway', 21, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2079, 'Henrico', 7, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2080, 'Hidalgo', 44, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2081, 'Lumpkin', 4, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2082, 'San Luis Obispo', 2, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2083, 'Asotin', 18, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2084, 'Valdez-Cordova', 14, '261', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2085, 'Mayagüez', 39, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2086, 'Washington', 37, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2087, 'Erie', 47, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2088, 'Mohave', 43, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2089, 'Lee', 38, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2090, 'Utuado', 39, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2091, 'Waushara', 5, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2092, 'Raleigh', 31, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2093, 'San Mateo', 2, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2094, 'Fulton', 20, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2095, 'Madison', 22, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2096, 'Clinton', 22, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2097, 'Norman', 16, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2098, 'Jefferson', 47, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2099, 'Holmes', 19, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2100, 'Comanche', 1, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2101, 'Rankin', 25, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2102, 'Nevada', 24, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2103, 'El Paso', 1, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2104, 'Guadalupe', 1, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2105, 'Grays Harbor', 18, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2106, 'Berrien', 4, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2107, 'Colquitt', 4, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2108, 'Coffee', 4, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2109, 'Emanuel', 4, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2110, 'Dixie', 13, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2111, 'Manassas', 7, '683', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2112, 'Baraga', 11, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2113, 'Pawnee', 48, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2114, 'Cattaraugus', 10, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2115, 'Tuscola', 11, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2116, 'Chippewa', 5, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2117, 'Muscatine', 22, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2118, 'Herkimer', 10, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2119, 'Banks', 4, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2120, 'Johnson', 48, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2121, 'York', 41, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2122, 'Jefferson', 18, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2123, 'Duplin', 27, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2124, 'Dukes', 33, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2125, 'Yauco', 39, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2126, 'Arecibo', 39, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2127, 'Chesapeake', 7, '550', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2128, 'Marshall', 22, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2129, 'Sequoyah', 29, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2130, 'Coconino', 43, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2131, 'Miami', 48, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2132, 'Coffee', 38, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2133, 'Spencer', 32, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2134, 'West Baton Rouge', 9, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2135, 'Los Angeles', 2, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2136, 'Custer', 12, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2137, 'Rawlins', 48, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2138, 'Morris', 48, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2139, 'Greenlee', 43, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2140, 'Dillingham', 14, '070', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2141, 'Mineral', 15, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2142, 'Washington', 5, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2143, 'Poweshiek', 22, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2144, 'Wheeler', 6, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2145, 'Franklin', 18, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2146, 'Kingman', 48, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2147, 'Lane', 6, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2148, 'Pulaski', 21, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2149, 'Stokes', 27, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2150, 'Logan', 26, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2151, 'Marion', 20, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2152, 'Flathead', 15, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2153, 'Washington', 41, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2154, 'San Bernardino', 2, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2155, 'Warren', 19, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2156, 'Victoria', 1, '469', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2157, 'Shackelford', 1, '417', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2158, 'Polk', 22, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2159, 'Ketchikan Gateway', 14, '130', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2160, 'Colbert', 38, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2161, 'Sitka', 14, '220', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2162, 'Union', 3, '225', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2163, 'Cache', 28, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2164, 'Washington', 17, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2165, 'Cherokee', 29, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2166, 'Laramie', 30, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2167, 'Gallatin', 15, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2168, 'Ulster', 10, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2169, 'Colusa', 2, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2170, 'Avery', 27, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2171, 'Rio Blanco', 26, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2172, 'Putnam', 19, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2173, 'Monroe', 4, '207', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2174, 'Huron', 11, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2175, 'Roanoke', 7, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2176, 'Columbia', 4, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2177, 'Harrison', 32, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2178, 'Cheyenne', 48, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2179, 'Berkshire', 33, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2180, 'Haines', 14, '100', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2181, 'Cook', 20, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2182, 'Summit', 19, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2183, 'La Plata', 26, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2184, 'Harris', 4, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2185, 'Mecklenburg', 27, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2186, 'Washington', 4, '303', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2187, 'Smith', 25, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2188, 'Ravalli', 15, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2189, 'Polk', 6, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2190, 'Wilkinson', 4, '319', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2191, 'Jim Wells', 1, '249', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2192, 'Toombs', 4, '279', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2193, 'Grayson', 3, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2194, 'Highland', 19, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2195, 'Dooly', 4, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2196, 'Nodaway', 21, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2197, 'Walthall', 25, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2198, 'Yakutat', 14, '282', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2199, 'Monroe', 25, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2200, 'Clark', 34, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2201, 'Potter', 23, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2202, 'Adams', 20, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2203, 'Shawano', 5, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2204, 'Liberty', 4, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2205, 'Meriwether', 4, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2206, 'Rockingham', 7, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2207, 'Randolph', 31, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2208, 'Hatillo', 39, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2209, 'Tunica', 25, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2210, 'Dimmit', 1, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2211, 'Kusilvak', 14, '158', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2212, 'Madison', 15, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2213, 'Lee', 7, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2214, 'Musselshell', 15, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2215, 'Beckham', 29, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2216, 'Passaic', 50, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2217, 'Wilbarger', 1, '487', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2218, 'Logan', 17, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2219, 'Tazewell', 7, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2220, 'Bartholomew', 32, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2221, 'Ritchie', 31, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2222, 'Tyler', 31, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2223, 'Roosevelt', 15, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2224, 'Imperial', 2, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2225, 'Carbon', 15, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2226, 'Ashland', 19, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2227, 'Lake', 2, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2228, 'Crook', 6, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2229, 'Cook', 16, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2230, 'Whitman', 18, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2231, 'Traill', 51, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2232, 'Lincoln', 24, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2233, 'Ray', 21, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2234, 'Pender', 27, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2235, 'Platte', 30, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2236, 'Iredell', 27, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2237, 'Clark', 48, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2238, 'Baltimore City', 45, '510', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2239, 'Madison', 38, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2240, 'Coosa', 38, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2241, 'Dodge', 5, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2242, 'Taylor', 13, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2243, 'Orange', 32, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2244, 'Bosque', 1, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2245, 'Hoonah-Angoon', 14, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2246, 'Merrick', 17, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2247, 'Loup', 17, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2248, 'Mason', 18, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2249, 'Roosevelt', 44, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2250, 'Middlesex', 35, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2251, 'Jackson', 16, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2252, 'Richland', 15, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2253, 'Oxford', 41, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2254, 'Morrison', 16, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2255, 'Baker', 6, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2256, 'Nantucket', 33, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2257, 'Franklin City', 7, '620', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2258, 'Hopewell', 7, '670', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2259, 'Perry', 24, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2260, 'Caguas', 39, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2261, 'Wasco', 6, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2262, 'Monroe', 24, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2263, 'Phillips', 24, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2264, 'Jackson', 32, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2265, 'George', 25, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2266, 'Bleckley', 4, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2267, 'Copiah', 25, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2268, 'Jackson', 31, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2269, 'Jeff Davis', 1, '243', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2270, 'Grant', 3, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2271, 'Portage', 5, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2272, 'Stanton', 17, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2273, 'Yell', 24, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2274, 'Spalding', 4, '255', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2275, 'Clarke', 7, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2276, 'Carolina', 39, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2277, 'Hawaii', 42, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2278, 'Blaine', 12, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2279, 'Taylor', 3, '217', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2280, 'Lawrence', 25, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2281, 'Polk', 17, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2282, 'Aiken', 40, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2283, 'Blount', 8, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2284, 'Hancock', 19, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2285, 'Pike', 4, '231', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2286, 'Stewart', 4, '259', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2287, 'Cuyahoga', 19, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2288, 'Fillmore', 17, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2289, 'Monona', 22, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2290, 'Oconto', 5, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2291, 'Kennebec', 41, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2292, 'Mitchell', 48, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2293, 'Oswego', 10, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2294, 'Grainger', 8, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2295, 'Madison', 25, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2296, 'Clearwater', 12, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2297, 'Sheridan', 30, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2298, 'Boone', 31, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2299, 'Deschutes', 6, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2300, 'Northumberland', 47, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2301, 'Pike', 38, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2302, 'Colorado', 1, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2303, 'Bartow', 4, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2304, 'Hardin', 8, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2305, 'Keith', 17, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2306, 'Greenwood', 40, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2307, 'DuPage', 20, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2308, 'Newton', 1, '351', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2309, 'Wood', 31, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2310, 'Madison', 13, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2311, 'Alleghany', 7, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2312, 'Hodgeman', 48, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2313, 'Columbiana', 19, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2314, 'Florence', 5, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2315, 'Worcester', 33, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2316, 'Floyd', 4, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2317, 'Teton', 15, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2318, 'Madera', 2, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2319, 'Teton', 12, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2320, 'Wheeler', 4, '309', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2321, 'Rock Island', 20, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2322, 'Shelby', 38, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2323, 'Aibonito', 39, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2324, 'Marion', 24, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2325, 'Yoakum', 1, '501', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2326, 'Lincoln', 17, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2327, 'Whitley', 3, '235', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2328, 'Graham', 43, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2329, 'Comerío', 39, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2330, 'Sussex', 46, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2331, 'Colonial Heights', 7, '570', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2332, 'Douglas', 23, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2333, 'Garfield', 28, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2334, 'Cottonwood', 16, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2335, 'Douglas', 18, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2336, 'Crenshaw', 38, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2337, 'Guayama', 39, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2338, 'Buchanan', 21, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2339, 'Lee', 13, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2340, 'Clallam', 18, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2341, 'Litchfield', 35, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2342, 'Lawrence', 20, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2343, 'Meade', 48, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2344, 'Clark', 32, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2345, 'Nassau', 10, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2346, 'Greer', 29, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2347, 'Lyon', 3, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2348, 'Magoffin', 3, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2349, 'Marshall', 3, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2350, 'Mason', 3, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2351, 'Salt Lake', 28, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2352, 'Bremer', 22, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2353, 'Cannon', 8, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2354, 'Wayne', 8, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2355, 'Jefferson', 31, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2356, 'Citrus', 13, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2357, 'Box Elder', 28, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2358, 'Washington', 7, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2359, 'Juneau', 14, '110', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2360, 'Saline', 24, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2361, 'Wabash', 32, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2362, 'Lafayette', 9, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2363, 'Knox', 41, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2364, 'Maverick', 1, '323', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2365, 'New Haven', 35, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2366, 'Harper', 48, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2367, 'Franklin', 12, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2368, 'Clear Creek', 26, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2369, 'Cumberland', 41, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2370, 'Brunswick', 7, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2371, 'Day', 23, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2372, 'Alger', 11, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2373, 'Valley', 12, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2374, 'Bell', 1, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2375, 'Hanover', 7, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2376, 'Refugio', 1, '391', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2377, 'Elbert', 26, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2378, 'Scioto', 19, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2379, 'Forest', 47, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2380, 'Pickett', 8, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2381, 'Monroe', 32, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2382, 'Young', 1, '503', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2383, 'Garden', 17, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2384, 'Spencer', 3, '215', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2385, 'Monroe', 3, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2386, 'Powell', 15, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2387, 'Livingston', 10, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2388, 'Randolph', 32, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2389, 'Bertie', 27, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2390, 'Beaufort', 27, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2391, 'Macomb', 11, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2392, 'Chippewa', 11, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2393, 'Scott', 8, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2394, 'Washington', 47, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2395, 'Bath', 7, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2396, 'White', 32, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2397, 'Early', 4, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2398, 'McKenzie', 51, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2399, 'Llano', 1, '299', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2400, 'Cotton', 29, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2401, 'Muskegon', 11, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2402, 'Pike', 3, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2403, 'Trigg', 3, '221', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2404, 'Lavaca', 1, '285', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2405, 'Mason', 11, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2406, 'Boyd', 3, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2407, 'Albemarle', 7, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2408, 'Grant', 31, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2409, 'Anderson', 48, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2410, 'Winona', 16, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2411, 'Scotland', 21, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2412, 'Lincoln', 15, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2413, 'Cayuga', 10, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2414, 'Kay', 29, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2415, 'Curry', 6, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2416, 'Bent', 26, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2417, 'Penobscot', 41, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2418, 'Somerset', 50, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2419, 'Fairfield', 40, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2420, 'Oliver', 51, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2421, 'Zavala', 1, '507', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2422, 'Seward', 48, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2423, 'Foard', 1, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2424, 'Sully', 23, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2425, 'Union', 6, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2426, 'Lincoln', 34, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2427, 'Wilcox', 38, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2428, 'Kiowa', 29, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2429, 'Yazoo', 25, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2430, 'Carroll', 32, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2431, 'Hinsdale', 26, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2432, 'Pettis', 21, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2433, 'Bayamón', 39, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2434, 'Saginaw', 11, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2435, 'Morgan', 32, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2436, 'Custer', 26, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2437, 'Garvin', 29, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2438, 'Camden', 27, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2439, 'Sevier', 8, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2440, 'Val Verde', 1, '465', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2441, 'Denali', 14, '068', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2442, 'Arapahoe', 26, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2443, 'Macon', 20, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2444, 'Cowlitz', 18, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2445, 'Polk', 13, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2446, 'Chattahoochee', 4, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2447, 'Sullivan', 32, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2448, 'Campbell', 3, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2449, 'Houghton', 11, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2450, 'San Juan', 44, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2451, 'Lincoln', 27, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2452, 'Montgomery', 4, '209', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2453, 'Moniteau', 21, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2454, 'Laurens', 4, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2455, 'Juneau', 5, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2456, 'Wood', 5, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2457, 'Red Lake', 16, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2458, 'Morgan', 19, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2459, 'Portage', 19, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2460, 'Pottawatomie', 29, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2461, 'Kearney', 17, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2462, 'McCracken', 3, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2463, 'Lafayette', 5, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2464, 'Greeley', 17, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2465, 'Jones', 27, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2466, 'Buckingham', 7, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2467, 'Taylor', 22, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2468, 'Sevier', 24, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2469, 'Hutchinson', 23, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2470, 'Franklin', 38, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2471, 'Martin', 13, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2472, 'Marion', 6, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2473, 'Kendall', 1, '259', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2474, 'Warren', 7, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2475, 'Polk', 5, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2476, 'Park', 30, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2477, 'Santa Rosa', 13, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2478, 'Lake', 19, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2479, 'Harlan', 3, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2480, 'Otero', 44, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2481, 'Logan', 20, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2482, 'Taos', 44, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2483, 'Grundy', 8, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2484, 'Harrison', 21, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2485, 'Tulsa', 29, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2486, 'Chenango', 10, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2487, 'Liberty', 1, '291', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2488, 'Washington', 29, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2489, 'Greene', 47, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2490, 'Fayette', 47, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2491, 'Highland', 7, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2492, 'Crittenden', 24, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2493, 'Tishomingo', 25, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2494, 'Osceola', 13, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2495, 'Geauga', 19, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2496, 'Columbia', 10, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2497, 'Sullivan', 21, '211', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2498, 'Jim Hogg', 1, '247', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2499, 'Vilas', 5, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2500, 'Lee', 1, '287', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2501, 'Washington', 13, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2502, 'Wyoming', 31, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2503, 'Doniphan', 48, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2504, 'Buffalo', 5, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2505, 'Gallia', 19, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2506, 'Perry', 19, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2507, 'Sioux', 17, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2508, 'Steuben', 10, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2509, 'Washoe', 34, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2510, 'Grant', 9, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2511, 'Tulare', 2, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2512, 'Giles', 8, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2513, 'Hyde', 27, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2514, 'Santa Clara', 2, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2515, 'Charles Mix', 23, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2516, 'Harford', 45, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2517, 'Orange', 13, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2518, 'Amite', 25, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2519, 'McPherson', 23, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2520, 'Nicholas', 31, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2521, 'Sussex', 50, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2522, 'Santa Fe', 44, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2523, 'Newton', 21, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2524, 'Lincoln', 41, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2525, 'Wicomico', 45, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2526, 'Amador', 2, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2527, 'Essex', 33, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2528, 'West Feliciana', 9, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2529, 'Barton', 48, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2530, 'Jones', 1, '253', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2531, 'Chattooga', 4, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2532, 'Cross', 24, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2533, 'Hancock', 41, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2534, 'Anderson', 8, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2535, 'Trinity', 1, '455', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2536, 'Tarrant', 1, '439', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2537, 'Yakima', 18, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2538, 'Greene', 8, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2539, 'Mahnomen', 16, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2540, 'Montezuma', 26, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2541, 'St. Mary''s', 45, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2542, 'Wabash', 20, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2543, 'Pitt', 27, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2544, 'Washington', 45, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2545, 'Golden Valley', 15, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2546, 'Stafford', 7, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2547, 'Delaware', 19, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2548, 'Hughes', 23, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2549, 'Butler', 22, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2550, 'Dallam', 1, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2551, 'Kingfisher', 29, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2552, 'Hemphill', 1, '211', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2553, 'Union', 22, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2554, 'Foster', 51, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2555, 'Gray', 1, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2556, 'Guaynabo', 39, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2557, 'Pulaski', 7, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2558, 'Montgomery', 25, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2559, 'Callahan', 1, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2560, 'Warren', 10, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2561, 'Clinch', 4, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2562, 'Carson City', 34, '510', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2563, 'Allen', 19, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2564, 'Custer', 29, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2565, 'Pinellas', 13, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2566, 'Humboldt', 22, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2567, 'Overton', 8, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2568, 'Cook', 4, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2569, 'Malheur', 6, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2570, 'Long', 4, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2571, 'Shoshone', 12, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2572, 'Harrison', 31, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2573, 'Dallas', 24, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2574, 'Putnam', 10, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2575, 'Caldwell', 9, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2576, 'King', 18, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2577, 'Lincoln', 30, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2578, 'Ozark', 21, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2579, 'Monroe', 11, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2580, 'Blackford', 32, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2581, 'Ellsworth', 48, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2582, 'Moody', 23, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2583, 'Columbia', 5, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2584, 'Jackson', 4, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2585, 'Rio Grande', 26, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2586, 'Peach', 4, '225', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2587, 'Bacon', 4, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2588, 'Monroe', 5, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2589, 'Stonewall', 1, '433', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2590, 'Owyhee', 12, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2591, 'Holt', 21, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2592, 'Dubois', 32, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2593, 'Humphreys', 25, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2594, 'Carter', 21, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2595, 'York', 40, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2596, 'Skamania', 18, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2597, 'Meigs', 19, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2598, 'Inyo', 2, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2599, 'Yancey', 27, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2600, 'Taney', 21, '213', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2601, 'Wetzel', 31, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2602, 'Cass', 22, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2603, 'Marinette', 5, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2604, 'Bladen', 27, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2605, 'Carter', 3, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2606, 'Fulton', 24, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2607, 'Grant', 5, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2608, 'Pope', 24, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2609, 'Richland', 5, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2610, 'Adams', 26, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2611, 'Atoka', 29, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2612, 'Lewis', 21, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2613, 'Bay', 13, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2614, 'Golden Valley', 51, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2615, 'Schley', 4, '249', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2616, 'Kenedy', 1, '261', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2617, 'Adair', 3, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2618, 'Ellis', 29, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2619, 'Windsor', 49, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2620, 'Campbell', 7, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2621, 'Perquimans', 27, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2622, 'Osborne', 48, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2623, 'Harnett', 27, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2624, 'Panola', 25, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2625, 'Atascosa', 1, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2626, 'Coke', 1, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2627, 'Summit', 28, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2628, 'Keweenaw', 11, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2629, 'Nolan', 1, '353', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2630, 'Shannon', 21, '203', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2631, 'Fremont', 26, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2632, 'Lake', 26, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2633, 'Garza', 1, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2634, 'Howard', 1, '227', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2635, 'Greene', 10, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2636, 'Newton', 24, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2637, 'Morris', 1, '343', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2638, 'Marshall', 31, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2639, 'Lauderdale', 8, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2640, 'Fleming', 3, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2641, 'Allen', 9, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2642, 'Halifax', 7, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2643, 'Pike', 47, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2644, 'Centre', 47, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2645, 'Coffee', 8, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2646, 'Montgomery', 1, '339', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2647, 'Pierce', 18, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2648, 'Talladega', 38, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2649, 'Chesterfield', 7, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2650, 'Posey', 32, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2651, 'Scott', 25, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2652, 'St. Charles', 21, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2653, 'Pinal', 43, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2654, 'Van Buren', 8, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2655, 'Marshall', 8, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2656, 'Archuleta', 26, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2657, 'Fulton', 47, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2658, 'Elk', 47, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2659, 'San Jacinto', 1, '407', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2660, 'Dakota', 17, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2661, 'Cherry', 17, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2662, 'Robertson', 3, '201', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2663, 'Union', 50, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2664, 'Okmulgee', 29, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2665, 'Brantley', 4, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2666, 'Hartford', 35, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2667, 'Dubuque', 22, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2668, 'Anne Arundel', 45, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2669, 'Liberty', 15, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2670, 'Ferry', 18, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2671, 'Elbert', 4, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2672, 'Niobrara', 30, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2673, 'Bonner', 12, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2674, 'New York', 10, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2675, 'Union', 25, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2676, 'Sioux', 51, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2677, 'Winnebago', 5, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2678, 'Gunnison', 26, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2679, 'Bonneville', 12, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2680, 'Union', 24, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2681, 'Crockett', 1, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2682, 'Placer', 2, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2683, 'Steuben', 32, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2684, 'Dougherty', 4, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2685, 'Perry', 38, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2686, 'East Carroll', 9, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2687, 'Christian', 3, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2688, 'McLean', 20, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2689, 'Transylvania', 27, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2690, 'Marengo', 38, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2691, 'Harrison', 19, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2692, 'Warren', 50, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2693, 'Wayne', 3, '231', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2694, 'Love', 29, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2695, 'Sibley', 16, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2696, 'Bedford', 7, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2697, 'Lawrence', 3, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2698, 'Bulloch', 4, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2699, 'Franklin', 41, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2700, 'McHenry', 20, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2701, 'Middlesex', 33, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2702, 'Atlantic', 50, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2703, 'Adams', 51, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2704, 'Adams', 25, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2705, 'Bolivar', 25, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2706, 'Cooke', 1, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2707, 'Clark', 20, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2708, 'Guthrie', 22, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2709, 'Sequatchie', 8, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2710, 'Fayette', 4, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2711, 'Marquette', 5, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2712, 'Macon', 27, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2713, 'Calvert', 45, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2714, 'Champaign', 20, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2715, 'Bernalillo', 44, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2716, 'Rusk', 1, '401', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2717, 'Coshocton', 19, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2718, 'Appanoose', 22, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2719, 'Knott', 3, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2720, 'Jefferson', 9, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2721, 'San Miguel', 44, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2722, 'Benton', 18, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2723, 'Clearfield', 47, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2724, 'Multnomah', 6, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2725, 'Kane', 28, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2726, 'Carroll', 21, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2727, 'Prince William', 7, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2728, 'Douglas', 17, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2729, 'Maricopa', 43, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2730, 'White', 24, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2731, 'Laurel', 3, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2732, 'Smith', 8, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2733, 'Leslie', 3, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2734, 'Letcher', 3, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2735, 'Marin', 2, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2736, 'Monroe', 20, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2737, 'Lassen', 2, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2738, 'Wayne', 31, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2739, 'Bradford', 47, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2740, 'Monroe', 13, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2741, 'Jefferson', 32, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2742, 'Floyd', 32, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2743, 'Pickens', 4, '227', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2744, 'Clinton', 21, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2745, 'Dearborn', 32, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2746, 'Berkeley', 40, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2747, 'Deaf Smith', 1, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2748, 'Alleghany', 27, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2749, 'Northwest Arctic', 14, '188', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2750, 'Lee', 3, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2751, 'Midland', 11, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2752, 'Lunenburg', 7, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2753, 'Howard', 17, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2754, 'Dillon', 40, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2755, 'Adair', 21, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2756, 'Shelby', 32, '145', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2757, 'Ramsey', 16, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2758, 'Floyd', 22, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2759, 'Delaware', 29, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2760, 'Latimer', 29, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2761, 'Lares', 39, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2762, 'Mariposa', 2, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2763, 'Pulaski', 3, '199', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2764, 'Washington', 22, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2765, 'Richmond', 7, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2766, 'Nash', 27, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2767, 'Willacy', 1, '489', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2768, 'Sumner', 48, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2769, 'Orange', 10, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2770, 'Mountrail', 51, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2771, 'Frederick', 45, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2772, 'Lampasas', 1, '281', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2773, 'Windham', 35, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2774, 'Richland', 51, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2775, 'Barceloneta', 39, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2776, 'Metcalfe', 3, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2777, 'Providence', 37, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2778, 'Guánica', 39, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2779, 'Hughes', 29, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2780, 'Moca', 39, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2781, 'Madison', 10, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2782, 'Fallon', 15, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2783, 'Concho', 1, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2784, 'Butte', 23, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2785, 'Gosper', 17, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2786, 'Kalkaska', 11, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2787, 'Bollinger', 21, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2788, 'Monroe', 21, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2789, 'Mower', 16, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2790, 'Falls Church', 7, '610', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2791, 'Stanley', 23, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2792, 'Grant', 23, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2793, 'Spartanburg', 40, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2794, 'Davis', 28, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2795, 'Washington', 38, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2796, 'St. Louis City', 21, '510', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2797, 'Calhoun', 40, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2798, 'Warren', 27, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2799, 'Pembina', 51, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2800, 'Glades', 13, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2801, 'Somerset', 47, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2802, 'Lincoln', 31, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2803, 'Washington', 32, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2804, 'Huron', 19, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2805, 'Uinta', 30, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2806, 'Macon', 38, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2807, 'Carver', 16, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2808, 'Tallapoosa', 38, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2809, 'Rock', 17, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2810, 'Jackson', 8, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2811, 'Upshur', 1, '459', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2812, 'Bailey', 1, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2813, 'Osceola', 11, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2814, 'Crawford', 22, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2815, 'Clermont', 19, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2816, 'Coweta', 4, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2817, 'Jefferson', 24, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2818, 'Smith', 1, '423', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2819, 'Lincoln', 9, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2820, 'Camden', 50, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2821, 'Emmons', 51, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2822, 'Ashtabula', 19, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2823, 'York', 17, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2824, 'Russell', 38, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2825, 'North Slope', 14, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2826, 'Chowan', 27, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2827, 'Choctaw', 29, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2828, 'Cameron', 1, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2829, 'Brown', 16, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2830, 'Esmeralda', 34, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2831, 'Lancaster', 7, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2832, 'Bates', 21, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2833, 'McMinn', 8, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2834, 'Churchill', 34, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2835, 'Sierra', 44, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2836, 'Marlboro', 40, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2837, 'Hopkins', 3, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2838, 'Catron', 44, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2839, 'Lafayette', 24, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2840, 'Hormigueros', 39, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2841, 'Erie', 19, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2842, 'Daniels', 15, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2843, 'Lowndes', 4, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2844, 'Craig', 7, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2845, 'Gregg', 1, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2846, 'Leavenworth', 48, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2847, 'Wichita', 1, '485', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2848, 'Montgomery', 32, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2849, 'Shelby', 20, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2850, 'Orange', 49, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2851, 'Humboldt', 34, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2852, 'Santa Isabel', 39, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2853, 'Fairbanks North Star', 14, '090', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2854, 'Perry', 32, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2855, 'Howard', 22, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2856, 'Limestone', 38, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2857, 'Murray', 16, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2858, 'Pike', 32, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2859, 'Mercer', 21, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2860, 'Cedar', 21, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2861, 'La Salle', 1, '283', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2862, 'Delaware', 32, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2863, 'Madison', 4, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2864, 'Manitowoc', 5, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2865, 'Wayne', 17, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2866, 'Maui', 42, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2867, 'Winnebago', 20, '201', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2868, 'Hardin', 20, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2869, 'Conway', 24, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2870, 'Arenac', 11, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2871, 'Douglas', 4, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2872, 'St. Joseph', 11, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2873, 'Van Buren', 11, '159', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2874, 'Duchesne', 28, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2875, 'Sumner', 8, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2876, 'Winchester', 7, '840', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2877, 'Blaine', 15, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2878, 'Suffolk', 10, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2879, 'Dallas', 38, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2880, 'Prince of Wales-Hyder', 14, '198', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2881, 'Beadle', 23, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2882, 'Mineral', 34, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2883, 'Montgomery', 21, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2884, 'Wayne', 19, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2885, 'Ellis', 48, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2886, 'Henry', 21, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2887, 'Holmes', 25, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2888, 'Hancock', 22, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2889, 'McIntosh', 29, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2890, 'Caswell', 27, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2891, 'Madison', 12, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2892, 'Yukon-Koyukuk', 14, '290', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2893, 'Washington', 20, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2894, 'Buffalo', 23, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2895, 'Whiteside', 20, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2896, 'Strafford', 52, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2897, 'Johnson', 20, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2898, 'Hot Spring', 24, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2899, 'Logan', 31, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2900, 'Fresno', 2, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2901, 'Bowie', 1, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2902, 'Deer Lodge', 15, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2903, 'Beaverhead', 15, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2904, 'Walworth', 5, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2905, 'Petersburg', 14, '195', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2906, 'Wichita', 48, '203', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2907, 'Montgomery', 22, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2908, 'Hennepin', 16, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2909, 'Owsley', 3, '189', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2910, 'Tyler', 1, '457', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2911, 'Schenectady', 10, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2912, 'Zapata', 1, '505', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2913, 'Cidra', 39, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2914, 'Kankakee', 20, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2915, 'Somerset', 41, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2916, 'Haskell', 29, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2917, 'Orleans', 10, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2918, 'Oneida', 10, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2919, 'Watonwan', 16, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2920, 'Union', 27, '179', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2921, 'Suwannee', 13, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2922, 'Yellowstone', 15, '111', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2923, 'Lackawanna', 47, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2924, 'Catoosa', 4, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2925, 'Chautauqua', 10, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2926, 'Osage', 21, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2927, 'Angelina', 1, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2928, 'Rutland', 49, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2929, 'Southeast Fairbanks', 14, '240', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2930, 'Orocovis', 39, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2931, 'Bureau', 20, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2932, 'Winn', 9, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2933, 'White Pine', 34, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2934, 'Laurens', 40, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2935, 'McClain', 29, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2936, 'Saratoga', 10, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2937, 'Hancock', 3, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2938, 'Barbour', 38, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2939, 'Brooks', 4, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2940, 'Major', 29, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2941, 'Howard', 45, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2942, 'Desha', 24, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2943, 'Turner', 4, '287', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2944, 'Pocahontas', 31, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2945, 'Tolland', 35, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2946, 'Wabaunsee', 48, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2947, 'Wayne', 25, '153', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2948, 'Lewis and Clark', 15, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2949, 'Mendocino', 2, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2950, 'Sublette', 30, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2951, 'Glenn', 2, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2952, 'Allegheny', 47, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2953, 'Nuckolls', 17, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2954, 'Lyon', 34, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2955, 'Baker', 13, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2956, 'Frederick', 7, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2957, 'Platte', 17, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2958, 'New Madrid', 21, '143', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2959, 'Greene', 24, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2960, 'Ingham', 11, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2961, 'Roane', 31, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2962, 'Dyer', 8, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2963, 'Bristol', 33, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2964, 'Fayette', 20, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2965, 'Cambria', 47, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2966, 'Miller', 24, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2967, 'Hardin', 19, '065', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2968, 'Henry', 38, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2969, 'Scott', 24, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2970, 'Barrow', 4, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2971, 'Putnam', 21, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2972, 'Valley', 15, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2973, 'Marion', 13, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2974, 'Lake', 20, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2975, 'Washington', 9, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2976, 'Mellette', 23, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2977, 'Meade', 3, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2978, 'Knox', 17, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2979, 'San Diego', 2, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2980, 'Surry', 27, '171', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2981, 'Stanton', 48, '187', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2982, 'Kittitas', 18, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2983, 'Robeson', 27, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2984, 'Siskiyou', 2, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2985, 'York', 47, '133', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2986, 'Sabine', 9, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2987, 'Scott', 7, '169', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2988, 'Nye', 34, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2989, 'Emmet', 11, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2990, 'Tangipahoa', 9, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2991, 'Lyman', 23, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2992, 'Whitley', 32, '183', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2993, 'Greene', 27, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2994, 'Crane', 1, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2995, 'Weston', 30, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2996, 'Hunt', 1, '231', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2997, 'Chouteau', 15, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2998, 'Paulding', 4, '223', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (2999, 'Hand', 23, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3000, 'Washington', 28, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3001, 'Rio Arriba', 44, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3002, 'Bayfield', 5, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3003, 'Swain', 27, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3004, 'Harris', 1, '201', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3005, 'St. Joseph', 32, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3006, 'Indiana', 47, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3007, 'Lamoille', 49, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3008, 'St. Landry', 9, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3009, 'Patillas', 39, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3010, 'Goochland', 7, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3011, 'Big Horn', 30, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3012, 'Tooele', 28, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3013, 'Columbus', 27, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3014, 'Itasca', 16, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3015, 'Lincoln', 6, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3016, 'Park', 26, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3017, 'Yolo', 2, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3018, 'Franklin', 19, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3019, 'Platte', 21, '165', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3020, 'St. Tammany', 9, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3021, 'Culpeper', 7, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3022, 'Jefferson', 26, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3023, 'Lake', 15, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3024, 'Ector', 1, '135', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3025, 'Marion', 40, '067', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3026, 'Wallowa', 6, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3027, 'Morovis', 39, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3028, 'Warren', 21, '219', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3029, 'Anderson', 3, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3030, 'Cascade', 15, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3031, 'Goliad', 1, '175', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3032, 'Morgan', 28, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3033, 'Kootenai', 12, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3034, 'St. Lawrence', 10, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3035, 'Chaffee', 26, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3036, 'Warren', 25, '149', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3037, 'Denver', 26, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3038, 'Perry', 21, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3039, 'Rockbridge', 7, '163', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3040, 'St. Bernard', 9, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3041, 'New Castle', 46, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3042, 'Osage', 29, '113', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3043, 'San Saba', 1, '411', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3044, 'Cameron', 9, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3045, 'Navajo', 43, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3046, 'Hertford', 27, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3047, 'LaSalle', 9, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3048, 'Presque Isle', 11, '141', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3049, 'Lincoln', 8, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3050, 'Putnam', 13, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3051, 'Johnston', 29, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3052, 'Mason', 20, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3053, 'Pitkin', 26, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3054, 'Tom Green', 1, '451', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3055, 'Hunterdon', 50, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3056, 'Mercer', 50, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3057, 'Cleburne', 24, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3058, 'Grant', 44, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3059, 'Kings', 10, '047', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3060, 'Cherokee', 48, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3061, 'Jackson', 48, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3062, 'Sweetwater', 30, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3063, 'Russell', 3, '207', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3064, 'Oldham', 3, '185', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3065, 'Jackson', 38, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3066, 'Christian', 21, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3067, 'Lander', 34, '015', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3068, 'Webb', 1, '479', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3069, 'Piscataquis', 41, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3070, 'Cape May', 50, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3071, 'Pointe Coupee', 9, '077', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3072, 'Miami-Dade', 13, '086', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3073, 'Pierce', 4, '229', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3074, 'Johnson', 8, '091', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3075, 'Cass', 16, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3076, 'Amherst', 7, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3077, 'Washington', 1, '477', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3078, 'Murray', 29, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3079, 'Polk', 1, '373', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3080, 'El Dorado', 2, '017', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3081, 'Ontonagon', 11, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3082, 'Richland', 9, '083', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3083, 'St. Mary', 9, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3084, 'Iberia', 9, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3085, 'Alexander', 27, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3086, 'Live Oak', 1, '297', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3087, 'Barnstable', 33, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3088, 'Vance', 27, '181', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3089, 'Saline', 17, '151', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3090, 'Accomack', 7, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3091, 'Carteret', 27, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3092, 'Marion', 4, '197', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3093, 'Belmont', 19, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3094, 'Page', 7, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3095, 'Jackson', 27, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3096, 'Wayne', 21, '223', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3097, 'Madison', 21, '123', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3098, 'Reeves', 1, '389', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3099, 'Mercer', 3, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3100, 'Torrance', 44, '057', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3101, 'Plaquemines', 9, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3102, 'Hart', 3, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3103, 'Wabasha', 16, '157', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3104, 'Clinton', 3, '053', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3105, 'Allendale', 40, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3106, 'Dallas', 21, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3107, 'Scott', 3, '209', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3108, 'Throckmorton', 1, '447', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3109, 'Jasper', 25, '061', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3110, 'Henry', 3, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3111, 'Lincoln', 44, '027', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3112, 'Cumberland', 27, '051', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3113, 'Fremont', 30, '013', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3114, 'Todd', 23, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3115, 'Douglas', 5, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3116, 'Jefferson', 25, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3117, 'Edmunds', 23, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3118, 'Bradley', 8, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3119, 'Nemaha', 48, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3120, 'Huerfano', 26, '055', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3121, 'Lincoln', 26, '073', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3122, 'Quay', 44, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3123, 'McLeod', 16, '085', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3124, 'Ward', 51, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3125, 'Grafton', 52, '009', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3126, 'Charlton', 4, '049', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3127, 'Genesee', 10, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3128, 'San Benito', 2, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3129, 'Orleans', 9, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3130, 'Canóvanas', 39, '029', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3131, 'Isle of Wight', 7, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3132, 'Johnson', 24, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3133, 'Woodruff', 24, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3134, 'Appling', 4, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3135, 'Treasure', 15, '103', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3136, 'Rosebud', 15, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3137, 'Dakota', 16, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3138, 'Rogers', 29, '131', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3139, 'Muskogee', 29, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3140, 'Terrebonne', 9, '109', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3141, 'Montgomery', 7, '121', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3142, 'Apache', 43, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3143, 'Caroline', 7, '033', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3144, 'Mills', 1, '333', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3145, 'Randall', 1, '381', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3146, 'Pasco', 13, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3147, 'Hall', 4, '139', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3148, 'Montgomery', 8, '125', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3149, 'Dorchester', 40, '035', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3150, 'Williamsburg', 7, '830', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3151, 'Piatt', 20, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3152, 'Van Wert', 19, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3153, 'Tensas', 9, '107', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3154, 'Pemiscot', 21, '155', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3155, 'East Feliciana', 9, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3156, 'Mingo', 31, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3157, 'Summit', 26, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3158, 'Douglas', 6, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3159, 'Kaufman', 1, '257', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3160, 'Rabun', 4, '241', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3161, 'McIntosh', 4, '191', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3162, 'Dewey', 29, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3163, 'Nassau', 13, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3164, 'Jasper', 21, '097', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3165, 'Elko', 34, '007', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3166, 'Pawnee', 29, '117', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3167, 'Kane', 20, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3168, 'Yellow Medicine', 16, '173', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3169, 'Polk', 16, '119', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3170, 'Stephenson', 20, '177', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3171, 'Fairfield', 35, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3172, 'Essex', 10, '031', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3173, 'Wrangell', 14, '275', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3174, 'Griggs', 51, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3175, 'Galveston', 1, '167', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3176, 'Pierce', 51, '069', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3177, 'Matanuska-Susitna', 14, '170', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3178, 'Yalobusha', 25, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3179, 'Harding', 44, '021', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3180, 'Lajas', 39, '079', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3181, 'Kent', 46, '001', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3182, 'Cheshire', 52, '005', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3183, 'Missoula', 15, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3184, 'Klickitat', 18, '039', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3185, 'Toa Baja', 39, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3186, 'Trinity', 2, '105', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3187, 'Stewart', 8, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3188, 'McCreary', 3, '147', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3189, 'Queens', 10, '081', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3190, 'Henderson', 27, '089', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3191, 'Garfield', 26, '045', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3192, 'Rutherford', 27, '161', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3193, 'St. Clair', 38, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3194, 'Mississippi', 24, '093', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3195, 'Daviess', 3, '059', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3196, 'Jefferson', 15, '043', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3197, 'Montgomery', 38, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3198, 'St. Martin', 9, '099', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3199, 'Lewis', 8, '101', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3200, 'Washington', 49, '023', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3201, 'Franklin', 13, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3202, 'Jackson', 13, '063', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3203, 'Levy', 13, '075', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3204, 'Wakulla', 13, '129', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3205, 'Wayne', 47, '127', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3206, 'Hamilton', 10, '041', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3207, 'Franklin', 49, '011', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3208, 'Harney', 6, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3209, 'Lake', 6, '037', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3210, 'Stillwater', 15, '095', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3211, 'Washington', 10, '115', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3212, 'Washington', 12, '087', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3213, 'St. Louis', 16, '137', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3214, 'Delaware', 10, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3215, 'Bergen', 50, '003', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3216, 'Koochiching', 16, '071', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3217, 'Boone', 21, '019', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3218, 'Aleutians West', 14, '016', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3219, 'Claiborne', 8, '025', NULL, NULL);
            INSERT INTO static.county (id, county_name, state_id, fips, alt_name, non_std)
            VALUES (3220, 'Broome', 10, '007', NULL, NULL);


--             --change to city
-- Maryland,510,Baltimore
-- Missouri,510,St. Louis
-- Virginia,770,Roanoke
-- Virginia,760,Richmond
-- Virginia,620,Franklin
-- Virginia,600,Fairfax

            INSERT INTO static.fips_lut(state, county_name, fips, alt_name)
            select s.abb, c.county_name, c.fips, c.alt_name from static.states s
            join static.county c ON c.state_id = s.id;

        end if;

    end;
$$;

