--
-- various useful queries on the new dschema
--

-- extracting cases and deaths for each county
-- NOTE: this is not the right way to get country, state, county names.  The names should be curated and stored in the 'regions' table.
create temporary table cases_deaths_county as
select
      provider_id
    , valid_time
    , split_part(region_id, '^', 1) as country
    , split_part(region_id, '^', 2) as state
    , split_part(region_id, '^', 3) as county
    , attr
    , val
from :myschema.attr_val
    natural join :myschema.scrapes
    natural join :myschema.regions
where
    resolution='county'
    and attr in ('cases', 'deaths')
order by 1,2,3,4,5;

-- pivot cases and deaths
-- NOTE: use crosstab if you need more columns in pivot
create TEMPORARY table cases_deaths_county_pivot as
select
      provider_id as provider
    , valid_time as "date"
    , country
    , state
    , county
    , max(val) filter (where attr='cases') as cases
    , max(val) filter (where attr='deaths') as deaths
from cases_deaths_county
group by 1,2,3,4,5
order by 1,2,3,4,5;

