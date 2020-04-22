FROM code.ornl.gov:4567/nset_covid19/covid19scrapers/base:latest

LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides the Scraper images for retrieving county-level \
COVID-19 confirmed cases"

WORKDIR /tmp

COPY scripts/ /tmp/scripts
COPY bin/ /tmp/bin

RUN ln -s /tmp/bin/py_runner.py /usr/local/bin/py_runner.py

COPY entrypoint.sh entrypoint.sh

ENTRYPOINT /tmp/entrypoint.sh
