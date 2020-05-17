FROM crunchydata/crunchy-postgres-gis:centos7-12.2-4.2.2
MAINTAINER Someone (someone@ornl.gov)
USER root
RUN sed -i -e "s/create database PG_DATABASE/create database PG_DATABASE WITH ENCODING = 'UTF8' TEMPLATE = template0/g" /opt/cpm/bin/setup.sql 

ADD pgconf/setup.sql /tmp/init.sql
ADD pgconf/setup-staging.sql /tmp/setup-staging.sql
ADD triggers.sql /tmp/triggers.sql
ADD views.sql /tmp/views.sql
ADD data /tmp/
ADD pgconf/post-start-hook.sh /pgconf/post-start-hook.sh
USER postgres
