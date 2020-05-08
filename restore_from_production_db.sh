#!/usr/bin/env bash

host=localhost
port=5432
restore_file="$1"
export PGPASSWORD=LovingLungfish

# Nuke Container and db volume
docker-compose rm -f db;
docker volume rm covidb_pg && docker volume create covidb_pg

# Force rebuild of db image and bring it up
docker-compose build --no-cache db && docker-compose up -d db

sleep 10
# Kill current connections
psql -h $host -p $port -U cvadmin -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'covidb' -- ← change this to your DB
  AND pid <> pg_backend_pid(); "

# Drop default db and create empty covidb
psql -h $host -p $port -U cvadmin -d postgres -c "DROP DATABASE IF EXISTS covidb;"
psql -h $host -p $port -U cvadmin -d postgres -c "CREATE DATABASE covidb with owner 'cvadmin';"

pg_restore $restore_file -h $host -p $port -U cvadmin -d covidb


