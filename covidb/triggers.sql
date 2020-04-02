\c covidb

-- =============================================
-- Author:      Bryan Eaton
-- Create date:  3/31/2020
-- Description: Trigger function to update Country, State and County scraping tables.
-- =============================================

create or replace function scraping.fn_update_scraping() returns trigger
    language plpgsql
as
$$
DECLARE
    v_page_id      int := (select id
                           from scraping.pages
                           where hash = digest(quote_literal(NEW.page), 'sha256')::varchar(64));
    v_scrape_group int := (select id
                           from scraping.scrape_group
                           where scrape_group = NEW.scrape_group);
    v_age_range    int := (select id
                           from scraping.age_ranges
                           where age_ranges.age_ranges = COALESCE(NEW.age_range, 'UNKNOWN'));
    v_url          int := (select id
                           from static.urls
                           where urls.url = NEW.url);

    v_fips int := (select id
                           from static.fips_lut l
                           where county_id = (select id from static.county where county_name = NEW.county
                           and state_id = (select id from static.states s where state = NEW.state)));

BEGIN

    IF (v_page_id is null) THEN
        INSERT INTO scraping.pages(page, url, hash, access_time)
        select NEW.page, NEW.url, digest(quote_literal(NEW.page), 'sha256')::varchar(64), NEW.access_time
        returning id into v_page_id;

    END IF;

    IF (v_scrape_group is null) THEN
        INSERT INTO scraping.scrape_group(scrape_group)
        select NEW.scrape_group
        returning id into v_scrape_group;

    END IF;

    IF (v_age_range is null) THEN
        INSERT INTO scraping.age_ranges(age_ranges)
        select COALESCE(NEW.age_range, 'UNKNOWN')
        returning id into v_age_range;
    end if;

    IF (v_url is null) THEN
        INSERT INTO static.urls(state_id, state, url)
        select (select id from static.states where state = NEW.state), NEW.state, NEW.url
        returning id into v_url;
    end if;

    RAISE NOTICE 'country: %', NEW.country;
    RAISE NOTICE 'state: %', NEW.state;
    RAISE NOTICE 'page: %', NEW.page;
    RAISE NOTICE 'scrape group: %', v_scrape_group;
    RAISE NOTICE 'age range: %', v_age_range;
    RAISE NOTICE 'url: %', v_url;
    RAISE NOTICE 'fips: %', v_fips;

    IF (NEW.county is null and NEW.state is null) THEN --Country Data


        INSERT INTO scraping.country_data (provider, country_id, region, access_time, url_id, page_id, cases,
                                           updated,
                                           deaths,
                                           presumptive,
                                           recovered,
                                           tested,
                                           hospitalized,
                                           negative,
                                           counties,
                                           severe,
                                           lat,
                                           lon,
                                           monitored,
                                           no_longer_monitored,
                                           pending,
                                           active,
                                           inconclusive,
                                           quarantined,
                                           scrape_group_id,
                                           resolution,
                                           icu,
                                           cases_male,
                                           cases_female,
                                           lab,
                                           lab_tests,
                                           lab_positive,
                                           lab_negative,
                                           age_range,
                                           age_cases,
                                           age_percent,
                                           age_deaths,
                                           age_hospitalized,
                                           age_tested,
                                           age_negative,
                                           age_hospitalized_percent,
                                           age_negative_percent,
                                           age_deaths_percent,
                                           sex,
                                           sex_counts,
                                           sex_percent,
                                           sex_death,
                                           other,
                                           other_value)
        select NEW.provider,
               (select id from static.country c where lower(NEW.country) = lower(c.country)),
               NEW.region,
               NEW.access_time,
               v_url,
               v_page_id,
               NEW.cases,
               date(timezone('UTC', NEW.updated)),
               NEW.presumptive,
               NEW.deaths,
               NEW.recovered,
               NEW.tested,
               NEW.hospitalized,
               NEW.negative,
               NEW.counties,
               NEW.severe,
               NEW.lat,
               NEW.lon,
               NEW.monitored,
               NEW.no_longer_monitored,
               NEW.pending,
               NEW.active,
               NEW.inconclusive,
               NEW.quarantined,
               v_scrape_group,
               NEW.resolution,
               NEW.icu,
               NEW.cases_male,
               NEW.cases_female,
               NEW.lab,
               NEW.lab_tests,
               NEW.lab_positive,
               NEW.lab_negative,
               v_age_range,
               NEW.age_cases,
               NEW.age_percent,
               NEW.age_deaths,
               NEW.age_hospitalized,
               NEW.age_tested,
               NEW.age_negative,
               NEW.age_hospitalized_percent,
               NEW.age_negative_percent,
               NEW.age_deaths_percent,
               NEW.sex,
               NEW.sex_counts,
               NEW.sex_percent,
               NEW.sex_death,
               NEW.other,
               NEW.other_value
        ON CONFLICT ON CONSTRAINT const_country
            DO UPDATE
            SET region = NEW.region,
               url_id = v_url,
               page_id = v_page_id,
               access_time = NEW.access_time,
               cases = NEW.cases,
               --updated = NEW.updated,
               deaths = NEW.deaths,
               presumptive = NEW.presumptive,
               recovered = NEW.recovered,
               tested = NEW.tested,
               hospitalized = NEW.hospitalized,
               negative = NEW.negative,
               severe = NEW.severe,
               lat = NEW.lat,
               lon = NEW.lon,
               monitored = NEW.monitored,
               no_longer_monitored = NEW.no_longer_monitored,
               pending = NEW.pending,
               active = NEW.active,
               inconclusive = NEW.inconclusive,
               quarantined = NEW.quarantined,
               scrape_group_id = v_scrape_group,
               resolution = NEW.resolution,
               icu = NEW.icu,
               cases_male = NEW.cases_male,
               cases_female = NEW.cases_female,
               lab = NEW.lab,
               lab_tests = NEW.lab_tests,
               lab_positive = NEW.lab_positive,
               lab_negative = NEW.lab_negative,
               age_cases = NEW.age_cases,
               age_percent = NEW.age_percent,
               age_deaths = NEW.age_deaths,
               age_hospitalized = NEW.age_hospitalized,
               age_tested = NEW.age_tested,
               age_negative = NEW.age_negative,
               age_hospitalized_percent = NEW.age_hospitalized_percent,
               age_negative_percent = NEW.age_negative_percent,
               age_deaths_percent = NEW.age_deaths_percent,
               sex_counts = NEW.sex_counts,
               sex_percent = NEW.sex_percent,
               sex_death = NEW.sex_death,
               other = NEW.other,
               other_value = NEW.other_value;


    end if;

    IF (NEW.state is not null and NEW.county is null) THEN --State Data


        INSERT INTO scraping.state_data (provider, country_id, state_id, region, access_time, url_id, page_id, cases,
                                           updated,
                                           deaths,
                                           presumptive,
                                           recovered,
                                           tested,
                                           hospitalized,
                                           negative,
                                           counties,
                                           severe,
                                           lat,
                                           lon,
                                           monitored,
                                           no_longer_monitored,
                                           pending,
                                           active,
                                           inconclusive,
                                           quarantined,
                                           scrape_group_id,
                                           resolution,
                                           icu,
                                           cases_male,
                                           cases_female,
                                           lab,
                                           lab_tests,
                                           lab_positive,
                                           lab_negative,
                                           age_range,
                                           age_cases,
                                           age_percent,
                                           age_deaths,
                                           age_hospitalized,
                                           age_tested,
                                           age_negative,
                                           age_hospitalized_percent,
                                           age_negative_percent,
                                           age_deaths_percent,
                                           sex,
                                           sex_counts,
                                           sex_percent,
                                         sex_death,
                                           other,
                                           other_value)
        select NEW.provider,
               (select id from static.country c where lower(NEW.country) = lower(c.country)),
               (select id from static.states s where lower(NEW.state) = lower(s.state)),
               NEW.region,
               NEW.access_time,
               v_url,
               v_page_id,
               NEW.cases,
               date(timezone('UTC', NEW.updated)),
               NEW.presumptive,
               NEW.deaths,
               NEW.recovered,
               NEW.tested,
               NEW.hospitalized,
               NEW.negative,
               NEW.counties,
               NEW.severe,
               NEW.lat,
               NEW.lon,
               NEW.monitored,
               NEW.no_longer_monitored,
               NEW.pending,
               NEW.active,
               NEW.inconclusive,
               NEW.quarantined,
               v_scrape_group,
               NEW.resolution,
               NEW.icu,
               NEW.cases_male,
               NEW.cases_female,
               NEW.lab,
               NEW.lab_tests,
               NEW.lab_positive,
               NEW.lab_negative,
               v_age_range,
               NEW.age_cases,
               NEW.age_percent,
               NEW.age_deaths,
               NEW.age_hospitalized,
               NEW.age_tested,
               NEW.age_negative,
               NEW.age_hospitalized_percent,
               NEW.age_negative_percent,
               NEW.age_deaths_percent,
               NEW.sex,
               NEW.sex_counts,
               NEW.sex_percent,
               NEW.sex_death,
               NEW.other,
               NEW.other_value
        ON CONFLICT ON CONSTRAINT const_state
            DO UPDATE
            SET region = NEW.region,
               url_id = v_url,
               page_id = v_page_id,
               access_time = NEW.access_time,
               cases = NEW.cases,
               --updated = NEW.updated,
               deaths = NEW.deaths,
               presumptive = NEW.presumptive,
               recovered = NEW.recovered,
               tested = NEW.tested,
               hospitalized = NEW.hospitalized,
               negative = NEW.negative,
               severe = NEW.severe,
               lat = NEW.lat,
               lon = NEW.lon,
               monitored = NEW.monitored,
               no_longer_monitored = NEW.no_longer_monitored,
               pending = NEW.pending,
               active = NEW.active,
               inconclusive = NEW.inconclusive,
               quarantined = NEW.quarantined,
               scrape_group_id = v_scrape_group,
               resolution = NEW.resolution,
               icu = NEW.icu,
               cases_male = NEW.cases_male,
               cases_female = NEW.cases_female,
               lab = NEW.lab,
               lab_tests = NEW.lab_tests,
               lab_positive = NEW.lab_positive,
               lab_negative = NEW.lab_negative,
               age_cases = NEW.age_cases,
               age_percent = NEW.age_percent,
               age_deaths = NEW.age_deaths,
               age_hospitalized = NEW.age_hospitalized,
               age_tested = NEW.age_tested,
               age_negative = NEW.age_negative,
               age_hospitalized_percent = NEW.age_hospitalized_percent,
               age_negative_percent = NEW.age_negative_percent,
               age_deaths_percent = NEW.age_deaths_percent,
               sex_counts = NEW.sex_counts,
               sex_percent = NEW.sex_percent,
                sex_death = NEW.sex_death,
               other = NEW.other,
               other_value = NEW.other_value;
    end if;

    IF (NEW.state is not null and NEW.county is not null) THEN --County Data


        INSERT INTO scraping.county_data (provider, country_id, state_id, county_id,fips_id, region, access_time, url_id, page_id, cases,
                                           updated,
                                           deaths,
                                           presumptive,
                                           recovered,
                                           tested,
                                           hospitalized,
                                           negative,
                                           counties,
                                           severe,
                                           lat,
                                           lon,
                                           monitored,
                                           no_longer_monitored,
                                           pending,
                                           active,
                                           inconclusive,
                                           quarantined,
                                           scrape_group_id,
                                           resolution,
                                           icu,
                                           cases_male,
                                           cases_female,
                                           lab,
                                           lab_tests,
                                           lab_positive,
                                           lab_negative,
                                           age_range,
                                           age_cases,
                                           age_percent,
                                           age_deaths,
                                           age_hospitalized,
                                           age_tested,
                                           age_negative,
                                           age_hospitalized_percent,
                                           age_negative_percent,
                                           age_deaths_percent,
                                           sex,
                                           sex_counts,
                                           sex_percent,
                                          sex_death,
                                           other,
                                           other_value)
        select NEW.provider,
               (select id from static.country c where lower(NEW.country) = lower(c.country)),
               (select id from static.states s where lower(NEW.state) = lower(s.state)),
               (select id from static.county c where lower(NEW.county) = lower(c.county_name) AND c.state_id = (select
                    id from static.states s where lower(NEW.state) = lower(s.state)) ),
               v_fips,
               NEW.region,
               NEW.access_time,
               v_url,
               v_page_id,
               NEW.cases,
               date(timezone('UTC', NEW.updated)),
               NEW.presumptive,
               NEW.deaths,
               NEW.recovered,
               NEW.tested,
               NEW.hospitalized,
               NEW.negative,
               NEW.counties,
               NEW.severe,
               NEW.lat,
               NEW.lon,
               NEW.monitored,
               NEW.no_longer_monitored,
               NEW.pending,
               NEW.active,
               NEW.inconclusive,
               NEW.quarantined,
               v_scrape_group,
               NEW.resolution,
               NEW.icu,
               NEW.cases_male,
               NEW.cases_female,
               NEW.lab,
               NEW.lab_tests,
               NEW.lab_positive,
               NEW.lab_negative,
               v_age_range,
               NEW.age_cases,
               NEW.age_percent,
               NEW.age_deaths,
               NEW.age_hospitalized,
               NEW.age_tested,
               NEW.age_negative,
               NEW.age_hospitalized_percent,
               NEW.age_negative_percent,
               NEW.age_deaths_percent,
               NEW.sex,
               NEW.sex_counts,
               NEW.sex_percent,
               NEW.sex_death,
               NEW.other,
               NEW.other_value
        ON CONFLICT ON CONSTRAINT const_county
            DO UPDATE
            SET region = NEW.region,
               url_id = v_url,
               page_id = v_page_id,
               access_time = NEW.access_time,
               cases = NEW.cases,
               --updated = NEW.updated,
               deaths = NEW.deaths,
               presumptive = NEW.presumptive,
               recovered = NEW.recovered,
               tested = NEW.tested,
               hospitalized = NEW.hospitalized,
               negative = NEW.negative,
               severe = NEW.severe,
               lat = NEW.lat,
               lon = NEW.lon,
               monitored = NEW.monitored,
               no_longer_monitored = NEW.no_longer_monitored,
               pending = NEW.pending,
               active = NEW.active,
               inconclusive = NEW.inconclusive,
               quarantined = NEW.quarantined,
               scrape_group_id = v_scrape_group,
               resolution = NEW.resolution,
               icu = NEW.icu,
               cases_male = NEW.cases_male,
               cases_female = NEW.cases_female,
               lab = NEW.lab,
               lab_tests = NEW.lab_tests,
               lab_positive = NEW.lab_positive,
               lab_negative = NEW.lab_negative,
               age_cases = NEW.age_cases,
               age_percent = NEW.age_percent,
               age_deaths = NEW.age_deaths,
               age_hospitalized = NEW.age_hospitalized,
               age_tested = NEW.age_tested,
               age_negative = NEW.age_negative,
               age_hospitalized_percent = NEW.age_hospitalized_percent,
               age_negative_percent = NEW.age_negative_percent,
               age_deaths_percent = NEW.age_deaths_percent,
               sex_counts = NEW.sex_counts,
               sex_percent = NEW.sex_percent,
               sex_death = NEW.sex_death,
               other = NEW.other,
               other_value = NEW.other_value;
    end if;
    /****** ENABLE in production ******/
    --delete from scraping.raw_data;
    RETURN NEW;

END
$$;

-- =============================================
-- Author:      Bryan Eaton
-- Create date:  3/31/2020
-- Description: Trigger object to execute fn_update_scraping
--              after each insert to raw_data.
-- =============================================
DROP TRIGGER IF EXISTS tr_raw_data on scraping.raw_data;
CREATE TRIGGER tr_raw_data
    AFTER INSERT
    ON scraping.raw_data
    FOR EACH ROW
EXECUTE PROCEDURE scraping.fn_update_scraping();


--TODO: Add Melt Trigger Func and obj.