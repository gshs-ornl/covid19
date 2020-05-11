
set client_encoding to 'UTF8';
truncate table scraping.melt cascade ;
truncate table scraping.attributes cascade ;
truncate table scraping.attribute_classes  cascade ;
truncate table scraping.provider cascade ;
truncate table scraping.scrape_group cascade ;
truncate table scraping.pages cascade ;

INSERT INTO scraping.provider(provider_abb, provider_name)
select provider_id, name from staging.provider;

INSERT INTO scraping.attributes (attribute)
select attr from staging.attr_def;

--This will probably come from python
INSERT INTO scraping.attribute_classes(name, units, class)
values ('Standard', 'count', 'Standard'),
       ('Age', 'count', 'Age'),
       ('Sex', 'count', 'Sex'),
       ('Race', 'count', 'Race'),
       ('Age, Sex, and Race', 'count', 'Other');

INSERT INTO scraping.scrape_group(provider_id, scrape_group)
select (select id from scraping.provider where provider_abb = scr.provider_id),cast(to_char(scraped_ts,'MMDDHH24MI') as integer)
from staging.scrapes scr
group by (select id from scraping.provider where provider_abb = scr.provider_id),cast(to_char(scraped_ts,'MMDDHH24MI') as integer);

--select * from scraping.scrape_group where scrape_group = '4101714';

INSERT INTO scraping.pages(page, url, hash, access_time)
select convert_to(doc, 'UTF8'), uri, null, scraped_ts from staging.scrapes;

--Load Country
drop table if exists country_load;
create temporary table country_load as
    select (select id from static.county c where upper(c.county_name) = 'UNKNOWN')                        as county_id,
           (select id from static.states s where upper(s.state) = 'UNKNOWN') as state_id,
           c.id as country_id,
           r.region_id,
           r.resolution,
           r.admin_lvl,
           v.valid_time                                                                                   as updated,
           s.scrape_id,
           s.scraped_ts,
           s.uri,
           v.attr,
           v.val,
           s.provider_id


    from staging.attr_val v
             join staging.attr_def d On d.attr = v.attr
             join staging.regions r ON r.region_id = v.region_id
             join staging.scrapes s ON s.scrape_id = v.scrape_id
             left join static.country c ON upper(c.country) = upper(split_part(replace(r.region_id,'US', 'United States'), '$', 2))
    where r.admin_lvl = 0 and c.country is not null;

INSERT INTO scraping.melt(country_id, state_id, county_id, updated, page_id, scrape_group, attribute_class, attribute, value)
select country_id,
       state_id,
       county_id,
       cast(updated as timestamp),
       (select id from scraping.pages p where p.access_time = d.scraped_ts AND p.url = d.uri limit 1),
       scrp.scrape_id,
        CASE WHEN d.attr ilike '%age%' then (select id from scraping.attribute_classes where class = 'Age')
                WHEN d.attr ilike '%sex%' then (select id from scraping.attribute_classes where class = 'Sex')
                WHEN d.attr ilike '%race%' then (select id from scraping.attribute_classes where class = 'Race')
                WHEN d.attr ilike '%ethnic%' AND d.attr ilike '%age%' then (select id from scraping.attribute_classes where class = 'Other')
               ELSE (select id from scraping.attribute_classes where class = 'Standard')
               END as attribute_class_id,
       (select id from scraping.attributes a where a.attribute = d.attr) as attribute_id,
       cast(val as numeric)
from country_load d
left join (select min(sg.id) as scrape_id, sg.scrape_group, p.provider_abb, p.id as provider_id
from scraping.scrape_group sg
join scraping.provider p ON p.id = sg.provider_id
group by scrape_group, p.provider_abb, p.id) scrp ON scrp.provider_abb = d.provider_id AND scrp.scrape_group = cast(to_char(scraped_ts,'MMDDHH24MI') as integer)
where staging.isnumeric(val) is true;

--Load County
drop table if exists county_load;

CREATE TEMPORARY TABLE county_load as
    select
           split_part(r.region_id, '^', 3) as county,
           (select id from static.states s where upper(s.state) = upper(split_part(replace(r.region_id,'$','^'), '^', 2))) as state_id,
           (select id from static.country c where upper(c.country) = upper('United States')) as country_id,
           r.resolution,
           r.admin_lvl,
           v.valid_time as updated,
           s.scrape_id,
           s.scraped_ts,
           s.uri,
           v.attr,
           v.val,
           s.provider_id
    from staging.attr_val v
             join staging.attr_def d On d.attr = v.attr
             join staging.regions r ON r.region_id = v.region_id
             join staging.scrapes s ON s.scrape_id = v.scrape_id
    where r.admin_lvl = 2;

INSERT INTO scraping.melt(country_id, state_id, county_id, updated, page_id, scrape_group, attribute_class, attribute, value)
select country_id,
       state_id,
       (select id from static.county cnt where upper(cnt.county_name) = upper(d.county) and cnt.state_id = d.state_id),
       cast(updated as timestamp),
       (select id from scraping.pages p where p.access_time = d.scraped_ts AND p.url = d.uri limit 1),
       scrp.scrape_id,
        CASE WHEN d.attr ilike '%age%' then (select id from scraping.attribute_classes where class = 'Age')
                WHEN d.attr ilike '%sex%' then (select id from scraping.attribute_classes where class = 'Sex')
                WHEN d.attr ilike '%race%' then (select id from scraping.attribute_classes where class = 'Race')
                WHEN d.attr ilike '%ethnic%' AND d.attr ilike '%age%' then (select id from scraping.attribute_classes where class = 'Other')
               ELSE (select id from scraping.attribute_classes where class = 'Standard')
               END as attribute_class_id,
       (select id from scraping.attributes a where a.attribute = d.attr) as attribute_id,
       cast(val as numeric)
from county_load d
left join (select min(sg.id) as scrape_id, sg.scrape_group, p.provider_abb, p.id as provider_id
from scraping.scrape_group sg
join scraping.provider p ON p.id = sg.provider_id
group by scrape_group, p.provider_abb, p.id) scrp ON scrp.provider_abb = d.provider_id AND scrp.scrape_group = cast(to_char(scraped_ts,'MMDDHH24MI') as integer)
where staging.isnumeric(val) is true;

drop table if exists state_load;
create temporary table state_load as
    select (select id from static.county c where upper(c.county_name) = 'UNKNOWN')                        as county_id,
           upper(split_part(replace(r.region_id,'$','^'), '^', 2)) as state_text,
           (select id from static.states s where upper(s.state) = upper(split_part(replace(r.region_id,'$','^'), '^', 2))) as state_id,
           (select id from static.country c where upper(c.country) = upper('United States'))              as country_id,
           r.resolution,
           r.admin_lvl,
           v.valid_time                                                                                   as updated,
           s.scrape_id,
           s.scraped_ts,
           s.uri,
           v.attr,
           v.val, s.provider_id


    from staging.attr_val v
             join staging.attr_def d On d.attr = v.attr
             join staging.regions r ON r.region_id = v.region_id
             join staging.scrapes s ON s.scrape_id = v.scrape_id
    where r.admin_lvl = 1;

INSERT INTO scraping.melt(country_id, state_id, county_id, updated, page_id, scrape_group, attribute_class, attribute, value)
select country_id,
       state_id,
       county_id,
       cast(updated as timestamp),
       (select id from scraping.pages p where p.access_time = d.scraped_ts AND p.url = d.uri),
scrp.scrape_id,
       CASE
           WHEN d.attr ilike '%age%' then (select id from scraping.attribute_classes where class = 'Age')
           WHEN d.attr ilike '%sex%' then (select id from scraping.attribute_classes where class = 'Sex')
           WHEN d.attr ilike '%race%' then (select id from scraping.attribute_classes where class = 'Race')
           WHEN d.attr ilike '%ethnic%' AND d.attr ilike '%age%'
               then (select id from scraping.attribute_classes where class = 'Other')
           ELSE (select id from scraping.attribute_classes where class = 'Standard')
           END                                                           as attribute_class_id,
       (select id from scraping.attributes a where a.attribute = d.attr) as attribute_id,
       cast(val as numeric)
from state_load d
left join (select min(sg.id) as scrape_id, sg.scrape_group, p.provider_abb, p.id as provider_id
from scraping.scrape_group sg
join scraping.provider p ON p.id = sg.provider_id
group by scrape_group, p.provider_abb, p.id) scrp ON scrp.provider_abb = d.provider_id AND scrp.scrape_group = cast(to_char(scraped_ts,'MMDDHH24MI') as integer)
where staging.isnumeric(val) is true;


--Attribute Classes
--AGE
--SEX
--RACE
--AGE SEX AND RACE

--Consistance across column names
/*
select m.updated, cnt.county_name,state,a.attribute, m.value
from scraping.melt m
join scraping.attribute_classes c ON c.id = m.attribute_class
join scraping.attributes a ON a.id = m.attribute
join scraping.scrape_group sg ON sg.id = m.scrape_group
join static.county cnt ON cnt.id = m.county_id
join static.states st ON st.id = m.state_id
where state = 'New York' --and county_id = (select id from static.county sc where sc.county_name = 'UNKNOWN')
order by updated;

select sg.scrape_group, a.attribute, m.value
from scraping.melt m
join scraping.attribute_classes c ON c.id = m.attribute_class
join scraping.attributes a ON a.id = m.attribute
join static.states st ON st.id = m.state_id
join scraping.scrape_group sg ON sg.id = m.scrape_group
join static.county cnt ON cnt.id = m.county_id
where m.state_id = (select id from static.states s where s.state = 'Tennessee')
and m.county_id = (select id from static.county c where c.county_name = 'Blount' and c.state_id = (select id from static.states s where s.state = 'Tennessee'))

select * from scraping.pages;

select * from staging.scrapes;



select count(*) from staging.attr_val where staging.isnumeric(val) is true;
select * from staging.provider;
*/

-- select r.region_id, r.admin_lvl, count(*)
--     from staging.attr_val v
--              join staging.attr_def d On d.attr = v.attr
--              join staging.regions r ON r.region_id = v.region_id
--              join staging.scrapes s ON s.scrape_id = v.scrape_id
--     group by r.region_id, r.admin_lvl;
