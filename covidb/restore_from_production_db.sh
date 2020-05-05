#!/usr/bin/env bash

host_name="$1"
restore_file="$2"
export PGPASSWORD=LovingLungfish


echo $1
echo $2
psql -h $1 -p 5432 -U cvadmin -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'covidb' -- ← change this to your DB
  AND pid <> pg_backend_pid(); "

psql -h $1 -p 5432 -U cvadmin -d postgres -c "DROP DATABASE IF EXISTS covidb;"

psql -h $1 -p 5432 -U cvadmin -d postgres -c "CREATE DATABASE covidb with owner 'cvadmin';"

pg_restore $2 -h $1 -p 5432 -U cvadmin -d covidb
