#!/bin/sh

echo "setting stuff up"
MAX_RETRIES=60
RETRIES_REMAINING=${MAX_RETRIES}
#until psql -h /tmp -U postgres -d coviddb -c "select count(*) from cvadmin.testtable"
until /usr/pgsql-12/bin/pg_isready  -h /tmp -p 5432 -U cvadmin -d covidb
do
    sleep 1
    echo "retrying db connection..."
    RETRIES_REMAINING=$((RETRIES_REMAINING - 1))
    if [ "${RETRIES_REMAINING}" -lt 1 ]
    then
        echo "************************** GIVING UP ON DATABASE CONNECTION AFTER ${MAX_RETRIES} RETRIES ***********************************"
        break;
    fi
done

sleep 5
echo "creating covid db objects"
psql -h /tmp -U postgres -d covidb -f /tmp/init.sql
# psql -h /tmp -U postgres -d covidb -f /tmp/data.sql
psql -h /tmp -U postgres -d covidb -f /tmp/triggers.sql
psql -h /tmp -U postgres -d covidb -f /tmp/views.sql
echo "loading data"
psql -d covidb -c "COPY static.country FROM '/tmp/static_country.csv' DELIMITER ',' CSV;"
psql -d covidb -c "COPY static.states FROM '/tmp/static_states.csv' DELIMITER ',' CSV;"
psql -d covidb -c "COPY static.county FROM '/tmp/static_county.csv' DELIMITER ',' CSV;"
psql -d covidb -c "COPY static.fips_lut FROM '/tmp/fips_lut.csv' DELIMITER ',' CSV;"
echo "finished setting stuff up"
