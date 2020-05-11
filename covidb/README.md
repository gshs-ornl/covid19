# Launching and populating a stand-alone staging database

## Instant PostGIS database

Permissions on the data directory are wrong but it's temporary

```
docker run --rm --name covidb2 -e POSTGRES_PASSWORD=covidb2 -e PGDATA=/data -v $PWD/data:/data -p 5433:5432 -d postgis/postgis
```

## Connect via another container

```
docker run -it --link covidb2:postgres --rm postgres sh -c 'exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres'
```

## Create database from psql

```
CREATE ROLE covidb2 WITH LOGIN PASSWORD 'covidb2';
create database covidb2 owner covidb2;
```

## Connect from the local system

```
PGPASSWORD=covidb2 psql -p 5433 -h localhost -U covidb2 covidb2
```

## Create schema

use the script `pgconf/setup.sql`

## Create SQL Dump (pg_dumpall from localhost)

```
PGPASSWORD=covidb2 pg_dumpall -d "postgresql://postgres:covidb2@localhost:5433/covidb2" | gzip > covidb2.$(date -Is).dump_all.gz

