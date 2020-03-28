FROM code.ornl.gov:4567/nset_covid19/covid19scrapers/base:latest

LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides the Scraper images for retrieving county-level \
COVID-19 confirmed cases"

WORKDIR /tmp

COPY scripts/ /tmp/scripts
COPY bin/ /tmp/bin

RUN ln -s /tmp/bin/bash_scraper.sh /usr/local/bin/bash_scraper.sh && \
      ln -s /tmp/bin/cron_scraper.R /usr/local/bin/cron_scraper.R && \
      ln -s /tmp/bin/scheduler.py /usr/local/bin/scheduler.py

COPY entrypoint.sh entrypoint.sh

ENTRYPOINT /tmp/entrypoint.sh
