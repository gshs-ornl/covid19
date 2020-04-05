FROM code.ornl.gov:4567/nset_covid19/covid19scrapers/base:latest

LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides the Scraper images for retrieving county-level \
COVID-19 confirmed cases"

WORKDIR /tmp

COPY .pgpass /root/
RUN chmod u-x,go-rwx /root/.pgpass

COPY bin/ /tmp/bin

RUN ln -s /tmp/bin/ingester.R /usr/local/bin/ingester.R && \
      ln -s /tmp/bin/slurper.py /usr/local/bin/slurper.py && \
      ln -s /tmp/bin/scheduler.py /usr/local/bin/scheduler.py && \
      ln -s /tmp/bin/create_views.sql /usr/local/bin/create_views.sql

COPY entrypoint.sh entrypoint.sh

ENTRYPOINT /tmp/entrypoint.sh
