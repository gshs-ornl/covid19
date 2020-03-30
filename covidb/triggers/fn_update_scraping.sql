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
                                        age_deaths_percent, scrape_group, page_id)
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
                scrape_group             = v_scrape_group;
    end if;

    IF (NEW.state is not null AND NEW.county is not null) THEN --Typical County Data

        INSERT INTO scraping.county_data(country_id, state_id, county_id, access_time, updated, cases, deaths,
                                         presumptive, tested,
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
                                         age_deaths_percent, scrape_group, page_id)
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
                scrape_group             = v_scrape_group;
    end if;

    RETURN NEW;
END
$$;