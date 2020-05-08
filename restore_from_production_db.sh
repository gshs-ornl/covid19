#!/usr/bin/env bash

host=localhost
port=5432
restore_file="$1"
export PGPASSWORD=LovingLungfish


psql -h $host -p $port -U cvadmin -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'covidb' -- ← change this to your DB
  AND pid <> pg_backend_pid(); "

psql -h $host -p $port -U cvadmin -d postgres -c "DROP DATABASE IF EXISTS covidb;"

psql -h $host -p $port -U cvadmin -d postgres -c "CREATE DATABASE covidb with owner 'cvadmin';"

pg_restore $restore_file -h $host -p $port -U cvadmin -d covidb
