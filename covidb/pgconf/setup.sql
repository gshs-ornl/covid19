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
     (id SERIAL PRIMARY KEY, country_id int REFERENCES static.country(id),fips varchar(2), abb varchar(2), state varchar)
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

--TODO: Add planetsense tables

GRANT USAGE ON SCHEMA scraping TO reporters, jesters, cvadmin;
GRANT USAGE ON SCHEMA static TO reporters, jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA scraping,static TO reporters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scraping TO jesters, cvadmin;
GRANT SELECT ON ALL TABLES IN SCHEMA static TO jesters;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA static TO ingester, cvadmin;


/**************** Country Data *********************/

truncate table static.country restart identity cascade ;

create temporary table iso_lookup
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


INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (3, 'Akrotiri (UK)', 'United Kingdom of Great Britain and Northern Ireland', 'GB', 'GBR', '826', true, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (16, 'Ashmore & Cartier Is (Aus)', 'Australia', 'AU', 'AUS', '36', true, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (1, 'Abyei (disp)', 'Abyei (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (4, 'Aksai Chin (disp)', 'Aksai Chin (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (210, 'Sanafir & Tiran Is. (disp)', 'Sanafir & Tiran Is. (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (214, 'Senkakus (disp)', 'Senkakus (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (135, 'Siachen-Saltoro (disp)', 'Siachen-Saltoro (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (225, 'Spratly Is (disp)', 'Spratly Is (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (7, 'American Samoa (US)', 'American Samoa', 'AS', 'ASM', '16', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (30, 'Bouvet Island (Nor)', 'Bouvet Island', 'BV', 'BVT', '74', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (42, 'British Indian Oc Terr (UK)', 'British Indian Ocean Territory', 'IO', 'IOT', '86', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (56, 'Cayman Is (UK)', 'Cayman Islands', 'KY', 'CYM', '136', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (57, 'Central African Rep', 'Central African Republic', 'CF', 'CAF', '140', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (37, 'Christmas I (Aus)', 'Christmas Island', 'CX', 'CXR', '162', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (32, 'Cocos (Keeling) Is (Aus)', 'Cocos (Keeling) Islands', 'CC', 'CCK', '166', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (39, 'Congo, Dem Rep of the', 'Congo, Democratic Republic of the', 'CD', 'COD', '180', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (80, 'Falkland Islands (UK) (disp)', 'Falkland Islands (Malvinas)', 'FK', 'FLK', '238', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (86, 'French Guiana (Fr)', 'French Guiana', 'GF', 'GUF', '254', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (87, 'French Polynesia (Fr)', 'French Polynesia', 'PF', 'PYF', '258', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (98, 'Gibraltar (UK)', 'Gibraltar', 'GI', 'GIB', '292', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (100, 'Greenland (Den)', 'Greenland', 'GL', 'GRL', '304', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (13, 'Anguilla (UK)', 'Anguilla', 'AI', 'AIA', '660', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (174, 'Netherlands [Caribbean]', 'Bonaire, Sint Eustatius and Saba', 'BQ', 'BES', '535', false, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (58, 'CH-IN (disp)', 'CH-IN (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (179, 'No Man''s Land (disp)', 'No Man''s Land (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (175, 'New Caledonia (Fr)', 'New Caledonia', 'NC', 'NCL', '540', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (102, 'Guadeloupe (Fr)', 'Guadeloupe', 'GP', 'GLP', '312', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (119, 'Hong Kong (Ch)', 'Hong Kong', 'HK', 'HKG', '344', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (138, 'Isle of Man (UK)', 'Isle of Man', 'IM', 'IMN', '833', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (166, 'Marshall Is', 'Marshall Islands', 'MH', 'MHL', '584', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (167, 'Martinique (Fr)', 'Martinique', 'MQ', 'MTQ', '474', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (172, 'Micronesia, Fed States of', 'Micronesia (Federated States of)', 'FM', 'FSM', '583', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (90, 'Montserrat (UK)', 'Montserrat', 'MS', 'MSR', '500', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (9, 'Antigua & Barbuda', 'Antigua and Barbuda', 'AG', 'ATG', '28', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (20, 'Bahamas, The', 'Bahamas', 'BS', 'BHS', '44', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (25, 'Bermuda (UK)', 'Bermuda', 'BM', 'BMU', '60', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (27, 'Bolivia', 'Bolivia (Plurinational State of)', 'BO', 'BOL', '68', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (28, 'Bosnia & Herzegovina', 'Bosnia and Herzegovina', 'BA', 'BIH', '70', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (43, 'Brunei', 'Brunei Darussalam', 'BN', 'BRN', '96', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (41, 'Cook Is (NZ)', 'Cook Islands', 'CK', 'COK', '184', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (81, 'Faroe Is (Den)', 'Faroe Islands', 'FO', 'FRO', '234', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (180, 'Norfolk I (Aus)', 'Norfolk Island', 'NF', 'NFK', '574', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (181, 'Northern Mariana Is (US)', 'Northern Mariana Islands', 'MP', 'MNP', '580', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (197, 'Puerto Rico (US)', 'Puerto Rico', 'PR', 'PRI', '630', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (211, 'Sao Tome & Principe', 'Sao Tome and Principe', 'ST', 'STP', '678', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (215, 'Sint Maarten (Neth)', 'Sint Maarten (Dutch part)', 'SX', 'SXM', '534', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (218, 'Solomon Is', 'Solomon Islands', 'SB', 'SLB', '90', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (237, 'Svalbard (Nor)', 'Svalbard and Jan Mayen', 'SJ', 'SJM', '744', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (207, 'Trinidad & Tobago', 'Trinidad and Tobago', 'TT', 'TTO', '780', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (258, 'Venezuela', 'Venezuela (Bolivarian Republic of)', 'VE', 'VEN', '862', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (94, 'Gaza Strip (disp)', 'Palestine, State of', 'PS', 'PSE', '275', false, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (84, 'Fr S & Antarctic Lands (Fr)', 'French Southern Territories', 'TF', 'ATF', '260', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (223, 'Spain [Canary Is]', 'Spain', 'ES', 'ESP', '724', false, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (224, 'Spain [Plazas de Soberania]', 'Spain', 'ES', 'ESP', '724', false, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (67, 'Dhekelia (UK)', 'United Kingdom of Great Britain and Northern Ireland', 'GB', 'GBR', '826', true, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (51, 'Coral Sea Is (Aus)', 'Australia', 'AU', 'AUS', '36', true, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (38, 'Clipperton I (Fr)', 'France', 'FR', 'FRA', '250', null, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (141, 'Jan Mayen (Nor)', 'Norway', 'NO', 'NOR', '578', null, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (195, 'Portugal [Azores]', 'Portugal', 'PT', 'PRT', '620', null, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (196, 'Portugal [Madeira Is]', 'Portugal', 'PT', 'PRT', '620', null, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (159, 'Macedonia', 'North Macedonia', 'MK', 'MKD', '807', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (89, 'Gambia, The', 'Gambia', 'GM', 'GMB', '270', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (109, 'Guernsey (UK)', 'Guernsey', 'GG', 'GGY', '831', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (117, 'Heard I & McDonald Is (Aus)', 'Heard Island and McDonald Islands', 'HM', 'HMD', '334', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (114, 'Jersey (UK)', 'Jersey', 'JE', 'JEY', '832', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (170, 'Mayotte (Fr)', 'Mayotte', 'YT', 'MYT', '175', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (173, 'Moldova', 'Moldova, Republic of', 'MD', 'MDA', '498', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (50, 'Canada', 'Canada', 'CA', 'CAN', '124', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (59, 'Chad', 'Chad', 'TD', 'TCD', '148', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (60, 'Chile', 'Chile', 'CL', 'CHL', '152', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (61, 'China', 'China', 'CN', 'CHN', '156', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (33, 'Colombia', 'Colombia', 'CO', 'COL', '170', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (34, 'Comoros', 'Comoros', 'KM', 'COM', '174', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (52, 'Costa Rica', 'Costa Rica', 'CR', 'CRI', '188', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (54, 'Croatia', 'Croatia', 'HR', 'HRV', '191', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (55, 'Cuba', 'Cuba', 'CU', 'CUB', '192', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (63, 'Cyprus', 'Cyprus', 'CY', 'CYP', '196', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (64, 'Czechia', 'Czechia', 'CZ', 'CZE', '203', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (66, 'Denmark', 'Denmark', 'DK', 'DNK', '208', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (68, 'Djibouti', 'Djibouti', 'DJ', 'DJI', '262', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (69, 'Dominica', 'Dominica', 'DM', 'DMA', '212', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (70, 'Dominican Republic', 'Dominican Republic', 'DO', 'DOM', '214', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (73, 'Ecuador', 'Ecuador', 'EC', 'ECU', '218', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (74, 'Egypt', 'Egypt', 'EG', 'EGY', '818', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (75, 'El Salvador', 'El Salvador', 'SV', 'SLV', '222', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (76, 'Equatorial Guinea', 'Equatorial Guinea', 'GQ', 'GNQ', '226', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (110, 'Guinea', 'Guinea', 'GN', 'GIN', '324', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (111, 'Guinea-Bissau', 'Guinea-Bissau', 'GW', 'GNB', '624', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (112, 'Guyana', 'Guyana', 'GY', 'GUY', '328', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (113, 'Haiti', 'Haiti', 'HT', 'HTI', '332', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (118, 'Honduras', 'Honduras', 'HN', 'HND', '340', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (130, 'Korea, North', 'Korea (Democratic People''s Republic of)', 'KP', 'PRK', '408', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (131, 'Korea, South', 'Korea, Republic of', 'KR', 'KOR', '410', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (15, 'Aruba (Neth)', 'Aruba', 'AW', 'ABW', '533', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (275, 'Burma', 'Myanmar', 'MM', 'MMR', '104', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (40, 'Congo, Rep of the', 'Congo', 'CG', 'COG', '178', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (53, 'Cote d''Ivoire', 'Côte d''Ivoire', 'CI', 'CIV', '384', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (62, 'Curacao (Neth)', 'Curaçao', 'CW', 'CUW', '531', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (123, 'Iran', 'Iran (Islamic Republic of)', 'IR', 'IRN', '364', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (145, 'Laos', 'Lao People''s Democratic Republic', 'LA', 'LAO', '418', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (31, 'Br Virgin Is (UK)', 'Virgin Islands (British)', 'VG', 'VGB', '92', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (35, 'Br Virgin Islands (UK)', 'Virgin Islands (British)', 'VG', 'VGB', '92', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (104, 'Guam (US)', 'Guam', 'GU', 'GUM', '316', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (158, 'Macau (Ch)', 'Macao', 'MO', 'MAC', '446', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (250, 'United Kingdom', 'United Kingdom of Great Britain and Northern Ireland', 'GB', 'GBR', '826', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (263, 'Western Sahara (disp)', 'Western Sahara', 'EH', 'ESH', '732', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (251, 'United States', 'United States of America', 'US', 'USA', '840', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (192, 'Pitcairn Is (UK)', 'Pitcairn', 'PN', 'PCN', '612', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (200, 'Russia', 'Russian Federation', 'RU', 'RUS', '643', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (242, 'Taiwan', 'Taiwan, Province of China[a]', 'TW', 'TWN', '158', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (244, 'Tanzania', 'Tanzania, United Republic of', 'TZ', 'TZA', '834', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (205, 'Tokelau (NZ)', 'Tokelau', 'TK', 'TKL', '772', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (229, 'Turks & Caicos Is (UK)', 'Turks and Caicos Islands', 'TC', 'TCA', '796', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (261, 'Wallis & Futuna (Fr)', 'Wallis and Futuna', 'WF', 'WLF', '876', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (2, 'Afghanistan', 'Afghanistan', 'AF', 'AFG', '4', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (5, 'Albania', 'Albania', 'AL', 'ALB', '8', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (6, 'Algeria', 'Algeria', 'DZ', 'DZA', '12', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (11, 'Andorra', 'Andorra', 'AD', 'AND', '20', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (12, 'Angola', 'Angola', 'AO', 'AGO', '24', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (8, 'Antarctica', 'Antarctica', 'AQ', 'ATA', '10', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (10, 'Argentina', 'Argentina', 'AR', 'ARG', '32', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (14, 'Armenia', 'Armenia', 'AM', 'ARM', '51', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (17, 'Australia', 'Australia', 'AU', 'AUS', '36', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (18, 'Austria', 'Austria', 'AT', 'AUT', '40', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (19, 'Azerbaijan', 'Azerbaijan', 'AZ', 'AZE', '31', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (268, 'Bahrain', 'Bahrain', 'BH', 'BHR', '48', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (274, 'Bangladesh', 'Bangladesh', 'BD', 'BGD', '50', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (21, 'Barbados', 'Barbados', 'BB', 'BRB', '52', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (22, 'Belarus', 'Belarus', 'BY', 'BLR', '112', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (23, 'Belgium', 'Belgium', 'BE', 'BEL', '56', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (24, 'Belize', 'Belize', 'BZ', 'BLZ', '84', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (277, 'Benin', 'Benin', 'BJ', 'BEN', '204', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (26, 'Bhutan', 'Bhutan', 'BT', 'BTN', '64', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (29, 'Botswana', 'Botswana', 'BW', 'BWA', '72', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (36, 'Brazil', 'Brazil', 'BR', 'BRA', '76', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (44, 'Bulgaria', 'Bulgaria', 'BG', 'BGR', '100', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (45, 'Burkina Faso', 'Burkina Faso', 'BF', 'BFA', '854', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (46, 'Burundi', 'Burundi', 'BI', 'BDI', '108', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (47, 'Cabo Verde', 'Cabo Verde', 'CV', 'CPV', '132', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (65, 'Demchok (disp)', 'Demchok (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (132, 'Kosovo', 'Republic of Kosovo', 'XK', 'XKX', '900', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (71, 'Dragonja (disp)', 'Dragonja (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (72, 'Dramana-Shakatoe (disp)', 'Dramana-Shakatoe (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (126, 'Isla Brasilera (disp)', 'Isla Brasilera (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (116, 'Kalapani (disp)', 'Kalapani (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (143, 'Koualou (disp)', 'Koualou (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (48, 'Cambodia', 'Cambodia', 'KH', 'KHM', '116', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (49, 'Cameroon', 'Cameroon', 'CM', 'CMR', '120', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (227, 'St Barthelemy (Fr)', 'Saint Barthélemy', 'BL', 'BLM', '652', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (228, 'St Helena (UK)', 'Saint Helena, Ascension and Tristan da Cunha', 'SH', 'SHN', '654', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (230, 'St Kitts & Nevis', 'Saint Kitts and Nevis', 'KN', 'KNA', '659', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (149, 'Liancourt Rocks (disp)', 'Liancourt Rocks (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (188, 'Paracel Is (disp)', 'Paracel Is (disp)', 'XX', 'XXX', '999', null, null);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (262, 'West Bank (disp)', 'Palestine, State of', 'PS', 'PSE', '275', false, true);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (231, 'St Lucia', 'Saint Lucia', 'LC', 'LCA', '662', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (232, 'St Martin (Fr)', 'Saint Martin (French part)', 'MF', 'MAF', '663', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (233, 'St Pierre & Miquelon (Fr)', 'Saint Pierre and Miquelon', 'PM', 'SPM', '666', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (234, 'St Vincent & the Grenadines', 'Saint Vincent and the Grenadines', 'VC', 'VCT', '670', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (241, 'Syria', 'Syrian Arab Republic', 'SY', 'SYR', '760', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (198, 'Reunion (Fr)', 'Réunion', 'RE', 'REU', '638', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (238, 'Swaziland', 'Eswatini', 'SZ', 'SWZ', '748', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (257, 'Vatican City', 'Holy See', 'VA', 'VAT', '336', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (259, 'Vietnam', 'Viet Nam', 'VN', 'VNM', '704', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (178, 'Niue (NZ)', 'Niue', 'NU', 'NIU', '570', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (254, 'US Virgin Is (US)', 'Virgin Islands (U.S.)', 'VI', 'VIR', '850', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (202, 'S Georgia & S Sandwich Is (UK)', 'South Georgia and the South Sandwich Islands', 'GS', 'SGS', '239', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (106, 'Navassa I (US)', 'United States Minor Outlying Islands', 'UM', 'UMI', '581', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (253, 'US Minor Pacific Is. Refuges (US)', 'United States Minor Outlying Islands', 'UM', 'UMI', '581', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (260, 'Wake I (US)', 'United States Minor Outlying Islands', 'UM', 'UMI', '581', false, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (77, 'Eritrea', 'Eritrea', 'ER', 'ERI', '232', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (78, 'Estonia', 'Estonia', 'EE', 'EST', '233', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (79, 'Ethiopia', 'Ethiopia', 'ET', 'ETH', '231', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (82, 'Fiji', 'Fiji', 'FJ', 'FJI', '242', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (83, 'Finland', 'Finland', 'FI', 'FIN', '246', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (85, 'France', 'France', 'FR', 'FRA', '250', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (88, 'Gabon', 'Gabon', 'GA', 'GAB', '266', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (95, 'Georgia', 'Georgia', 'GE', 'GEO', '268', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (96, 'Germany', 'Germany', 'DE', 'DEU', '276', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (97, 'Ghana', 'Ghana', 'GH', 'GHA', '288', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (99, 'Greece', 'Greece', 'GR', 'GRC', '300', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (101, 'Grenada', 'Grenada', 'GD', 'GRD', '308', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (105, 'Guatemala', 'Guatemala', 'GT', 'GTM', '320', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (120, 'Hungary', 'Hungary', 'HU', 'HUN', '348', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (121, 'Iceland', 'Iceland', 'IS', 'ISL', '352', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (276, 'India', 'India', 'IN', 'IND', '356', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (122, 'Indonesia', 'Indonesia', 'ID', 'IDN', '360', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (124, 'Iraq', 'Iraq', 'IQ', 'IRQ', '368', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (125, 'Ireland', 'Ireland', 'IE', 'IRL', '372', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (273, 'Israel', 'Israel', 'IL', 'ISR', '376', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (139, 'Italy', 'Italy', 'IT', 'ITA', '380', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (140, 'Jamaica', 'Jamaica', 'JM', 'JAM', '388', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (142, 'Japan', 'Japan', 'JP', 'JPN', '392', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (115, 'Jordan', 'Jordan', 'JO', 'JOR', '400', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (127, 'Kazakhstan', 'Kazakhstan', 'KZ', 'KAZ', '398', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (128, 'Kenya', 'Kenya', 'KE', 'KEN', '404', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (129, 'Kiribati', 'Kiribati', 'KI', 'KIR', '296', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (269, 'Kuwait', 'Kuwait', 'KW', 'KWT', '414', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (144, 'Kyrgyzstan', 'Kyrgyzstan', 'KG', 'KGZ', '417', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (146, 'Latvia', 'Latvia', 'LV', 'LVA', '428', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (147, 'Lebanon', 'Lebanon', 'LB', 'LBN', '422', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (148, 'Lesotho', 'Lesotho', 'LS', 'LSO', '426', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (150, 'Liberia', 'Liberia', 'LR', 'LBR', '430', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (151, 'Libya', 'Libya', 'LY', 'LBY', '434', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (152, 'Liechtenstein', 'Liechtenstein', 'LI', 'LIE', '438', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (153, 'Lithuania', 'Lithuania', 'LT', 'LTU', '440', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (154, 'Luxembourg', 'Luxembourg', 'LU', 'LUX', '442', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (160, 'Madagascar', 'Madagascar', 'MG', 'MDG', '450', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (161, 'Malawi', 'Malawi', 'MW', 'MWI', '454', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (162, 'Malaysia', 'Malaysia', 'MY', 'MYS', '458', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (163, 'Maldives', 'Maldives', 'MV', 'MDV', '462', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (164, 'Mali', 'Mali', 'ML', 'MLI', '466', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (165, 'Malta', 'Malta', 'MT', 'MLT', '470', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (168, 'Mauritania', 'Mauritania', 'MR', 'MRT', '478', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (169, 'Mauritius', 'Mauritius', 'MU', 'MUS', '480', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (171, 'Mexico', 'Mexico', 'MX', 'MEX', '484', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (155, 'Monaco', 'Monaco', 'MC', 'MCO', '492', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (156, 'Mongolia', 'Mongolia', 'MN', 'MNG', '496', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (157, 'Montenegro', 'Montenegro', 'ME', 'MNE', '499', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (91, 'Morocco', 'Morocco', 'MA', 'MAR', '504', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (92, 'Mozambique', 'Mozambique', 'MZ', 'MOZ', '508', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (93, 'Namibia', 'Namibia', 'NA', 'NAM', '516', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (103, 'Nauru', 'Nauru', 'NR', 'NRU', '520', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (107, 'Nepal', 'Nepal', 'NP', 'NPL', '524', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (108, 'Netherlands', 'Netherlands', 'NL', 'NLD', '528', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (176, 'New Zealand', 'New Zealand', 'NZ', 'NZL', '554', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (177, 'Nicaragua', 'Nicaragua', 'NI', 'NIC', '558', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (278, 'Niger', 'Niger', 'NE', 'NER', '562', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (279, 'Nigeria', 'Nigeria', 'NG', 'NGA', '566', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (182, 'Norway', 'Norway', 'NO', 'NOR', '578', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (183, 'Oman', 'Oman', 'OM', 'OMN', '512', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (184, 'Pakistan', 'Pakistan', 'PK', 'PAK', '586', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (185, 'Palau', 'Palau', 'PW', 'PLW', '585', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (186, 'Panama', 'Panama', 'PA', 'PAN', '591', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (187, 'Papua New Guinea', 'Papua New Guinea', 'PG', 'PNG', '598', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (189, 'Paraguay', 'Paraguay', 'PY', 'PRY', '600', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (190, 'Peru', 'Peru', 'PE', 'PER', '604', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (191, 'Philippines', 'Philippines', 'PH', 'PHL', '608', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (193, 'Poland', 'Poland', 'PL', 'POL', '616', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (194, 'Portugal', 'Portugal', 'PT', 'PRT', '620', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (270, 'Qatar', 'Qatar', 'QA', 'QAT', '634', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (199, 'Romania', 'Romania', 'RO', 'ROU', '642', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (201, 'Rwanda', 'Rwanda', 'RW', 'RWA', '646', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (203, 'Samoa', 'Samoa', 'WS', 'WSM', '882', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (204, 'San Marino', 'San Marino', 'SM', 'SMR', '674', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (212, 'Saudi Arabia', 'Saudi Arabia', 'SA', 'SAU', '682', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (213, 'Senegal', 'Senegal', 'SN', 'SEN', '686', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (133, 'Serbia', 'Serbia', 'RS', 'SRB', '688', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (134, 'Seychelles', 'Seychelles', 'SC', 'SYC', '690', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (136, 'Sierra Leone', 'Sierra Leone', 'SL', 'SLE', '694', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (137, 'Singapore', 'Singapore', 'SG', 'SGP', '702', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (216, 'Slovakia', 'Slovakia', 'SK', 'SVK', '703', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (217, 'Slovenia', 'Slovenia', 'SI', 'SVN', '705', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (219, 'Somalia', 'Somalia', 'SO', 'SOM', '706', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (220, 'South Africa', 'South Africa', 'ZA', 'ZAF', '710', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (221, 'South Sudan', 'South Sudan', 'SS', 'SSD', '728', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (222, 'Spain', 'Spain', 'ES', 'ESP', '724', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (226, 'Sri Lanka', 'Sri Lanka', 'LK', 'LKA', '144', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (235, 'Sudan', 'Sudan', 'SD', 'SDN', '729', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (236, 'Suriname', 'Suriname', 'SR', 'SUR', '740', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (239, 'Sweden', 'Sweden', 'SE', 'SWE', '752', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (240, 'Switzerland', 'Switzerland', 'CH', 'CHE', '756', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (243, 'Tajikistan', 'Tajikistan', 'TJ', 'TJK', '762', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (245, 'Thailand', 'Thailand', 'TH', 'THA', '764', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (246, 'Timor-Leste', 'Timor-Leste', 'TL', 'TLS', '626', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (247, 'Togo', 'Togo', 'TG', 'TGO', '768', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (206, 'Tonga', 'Tonga', 'TO', 'TON', '776', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (208, 'Tunisia', 'Tunisia', 'TN', 'TUN', '788', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (272, 'Turkey', 'Turkey', 'TR', 'TUR', '792', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (209, 'Turkmenistan', 'Turkmenistan', 'TM', 'TKM', '795', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (248, 'Tuvalu', 'Tuvalu', 'TV', 'TUV', '798', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (249, 'Uganda', 'Uganda', 'UG', 'UGA', '800', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (267, 'Ukraine', 'Ukraine', 'UA', 'UKR', '804', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (271, 'United Arab Emirates', 'United Arab Emirates', 'AE', 'ARE', '784', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (252, 'Uruguay', 'Uruguay', 'UY', 'URY', '858', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (255, 'Uzbekistan', 'Uzbekistan', 'UZ', 'UZB', '860', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (256, 'Vanuatu', 'Vanuatu', 'VU', 'VUT', '548', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (266, 'Yemen', 'Yemen', 'YE', 'YEM', '887', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (264, 'Zambia', 'Zambia', 'ZM', 'ZMB', '894', true, false);
INSERT INTO iso_lookup (cc_id, cc_name, iso_short_name, iso_alpha2_code, iso_alpha3_code, iso_numeric_code, iso_independent, inferred_match) VALUES (265, 'Zimbabwe', 'Zimbabwe', 'ZW', 'ZWE', '716', true, false);


insert into static.country(iso2c, iso3c, country)
select iso_alpha2_code, iso_alpha3_code, cc_name from iso_lookup;


INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (1, NULL, 'TX', 'Texas', '48');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (2, NULL, 'CA', 'California', '06');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (3, NULL, 'AK', 'Alaska', '02');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (4, NULL, 'KY', 'Kentucky', '21');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (5, NULL, 'VT', 'Vermont', '50');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (6, NULL, 'GA', 'Georgia', '13');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (7, NULL, 'NE', 'Nebraska', '31');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (8, NULL, 'WI', 'Wisconsin', '55');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (9, NULL, 'OR', 'Oregon', '41');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (10, NULL, 'WA', 'Washington', '53');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (11, NULL, 'VA', 'Virginia', '51');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (12, NULL, 'NJ', 'New Jersey', '34');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (13, NULL, 'TN', 'Tennessee', '47');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (14, NULL, 'OH', 'Ohio', '39');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (15, NULL, 'LA', 'Louisiana', '22');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (16, NULL, 'AL', 'Alabama', '01');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (17, NULL, 'NY', 'New York', '36');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (18, NULL, 'PR', 'Puerto Rico', '72');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (19, NULL, 'MI', 'Michigan', '26');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (20, NULL, 'ID', 'Idaho', '16');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (21, NULL, 'AR', 'Arkansas', '05');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (22, NULL, 'FL', 'Florida', '12');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (23, NULL, 'MT', 'Montana', '30');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (24, NULL, 'MS', 'Mississippi', '28');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (25, NULL, 'MN', 'Minnesota', '27');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (26, NULL, 'CO', 'Colorado', '08');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (27, NULL, 'RI', 'Rhode Island', '44');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (28, NULL, 'IL', 'Illinois', '17');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (29, NULL, 'MO', 'Missouri', '29');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (30, NULL, 'NM', 'New Mexico', '35');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (31, NULL, 'IA', 'Iowa', '19');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (32, NULL, 'SD', 'South Dakota', '46');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (33, NULL, 'NC', 'North Carolina', '37');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (34, NULL, 'UT', 'Utah', '49');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (35, NULL, 'ND', 'North Dakota', '38');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (36, NULL, 'OK', 'Oklahoma', '40');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (37, NULL, 'WY', 'Wyoming', '56');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (38, NULL, 'NH', 'New Hampshire', '33');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (39, NULL, 'WV', 'West Virginia', '54');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (40, NULL, 'IN', 'Indiana', '18');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (41, NULL, 'MA', 'Massachusetts', '25');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (42, NULL, 'NV', 'Nevada', '32');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (43, NULL, 'CT', 'Connecticut', '09');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (44, NULL, 'DC', 'District of Columbia', '11');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (45, NULL, 'SC', 'South Carolina', '45');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (46, NULL, 'ME', 'Maine', '23');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (47, NULL, 'HI', 'Hawaii', '15');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (48, NULL, 'AZ', 'Arizona', '04');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (49, NULL, 'DE', 'Delaware', '10');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (50, NULL, 'MD', 'Maryland', '24');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (51, NULL, 'PA', 'Pennsylvania', '42');
INSERT INTO static.states (id, country_id, abb, state, fips) VALUES (52, NULL, 'KS', 'Kansas', '20');


update static.states set country_id = (select id from static.country where country = 'United States');

