FROM code.ornl.gov:4567/nset_covid19/covid19scrapers/base:latest

LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides the testing image for the covid19scrapers project"

WORKDIR /tmp

COPY selenium_hub.py

CMD ['selenium_hub.py']
