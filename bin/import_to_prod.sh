#!/usr/bin/env bash
set -eux

import_schema=$1

# Dump from Alex's server
rm -rf /tmp/import
mkdir -p /tmp/import
export PGPASSWORD=covidb2 && psql -h ontoserv.ornl.gov -p 5433 -d covidb2 -U covidb2 -c "\COPY $import_schema.attr_def TO '/tmp/import/attr_def.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=covidb2 && psql -h ontoserv.ornl.gov -p 5433 -d covidb2 -U covidb2 -c "\COPY $import_schema.attr_val TO '/tmp/import/attr_val.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=covidb2 && psql -h ontoserv.ornl.gov -p 5433 -d covidb2 -U covidb2 -c "\COPY $import_schema.scrapes TO '/tmp/import/scrapes.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=covidb2 && psql -h ontoserv.ornl.gov -p 5433 -d covidb2 -U covidb2 -c "\COPY (select region_id, resolution, details from $import_schema.regions) TO '/tmp/import/regions.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=covidb2 && psql -h ontoserv.ornl.gov -p 5433 -d covidb2 -U covidb2 -c "\COPY $import_schema.provider TO '/tmp/import/provider.csv' DELIMITER ',' CSV HEADER;"
# Copy to production server
export PGPASSWORD=AngryMoose78 && psql -h nsetcovid19.ornl.gov -p 5432 -d covidb -U jesters -f init_schema.sql
export PGPASSWORD=AngryMoose78 && psql -h nsetcovid19.ornl.gov -p 5432 -d covidb -U jesters -c "\COPY staging.provider(provider_id, name, insert_ts) FROM '/tmp/import/provider.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=AngryMoose78 && psql -h nsetcovid19.ornl.gov -p 5432 -d covidb -U jesters -c "\COPY staging.regions(region_id, resolution, details) FROM '/tmp/import/regions.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=AngryMoose78 && psql -h nsetcovid19.ornl.gov -p 5432 -d covidb -U jesters -c "\COPY staging.scrapes(scrape_id, provider_id, uri, scraped_ts, doc, csv_file, csv_row) FROM '/tmp/import/scrapes.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=AngryMoose78 && psql -h nsetcovid19.ornl.gov -p 5432 -d covidb -U jesters -c "\COPY staging.attr_def(attr, details) FROM '/tmp/import/attr_def.csv' DELIMITER ',' CSV HEADER;"
export PGPASSWORD=AngryMoose78 && psql -h nsetcovid19.ornl.gov -p 5432 -d covidb -U jesters -c "\COPY staging.attr_val(scrape_id, region_id, valid_time, attr, val, ext, parser) FROM '/tmp/import/attr_val.csv' DELIMITER ',' CSV HEADER;"

# Reload melt table
export PGPASSWORD=AngryMoose78 && psql -h nsetcovid19.ornl.gov -p 5432 -d covidb -U jesters -f reinitialize_production_db.sql
#\COPY provider(provider_id, name, insert_ts) FROM '/tmp/import/provider.csv' DELIMITER ',' CSV HEADER;
#\COPY regions(region_id, region_type, details) FROM '/tmp/import/regions.csv' DELIMITER ',' CSV HEADER;
#\COPY scrapes(scrape_id, provider_id, uri, scraped_ts, doc, csv_file, csv_row) FROM '/tmp/import/scrapes.csv' DELIMITER ',' CSV HEADER;
#\COPY attr_def(attr, details) FROM '/tmp/import/attr_def.csv' DELIMITER ',' CSV HEADER;
#\COPY attr_val(scrape_id, region_id, valid_time, attr, val, ext, parser) FROM '/tmp/import/attr_val.csv' DELIMITER ',' CSV HEADER;
