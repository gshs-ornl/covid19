#!/usr/bin/env bash

host_name="$1"
port="$2"
restore_file="$3"
export PGPASSWORD=LovingLungfish


psql -h $1 -p $2 -U cvadmin -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'covidb' -- ← change this to your DB
  AND pid <> pg_backend_pid(); "

psql -h $1 -p $2 -U cvadmin -d postgres -c "DROP DATABASE IF EXISTS covidb;"

psql -h $1 -p $2 -U cvadmin -d postgres -c "CREATE DATABASE covidb with owner 'cvadmin';"

pg_restore $3 -h $1 -p $2 -U cvadmin -d covidb
