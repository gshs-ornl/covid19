FROM code.ornl.gov:4567/nset_covid19/covid19scrapers/base:latest

LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides the testing image for the covid19scrapers project"

WORKDIR /tmp

RUN mkdir -p /tmp/tests

COPY  tests/* /tmp/tests/
COPY entrypoint.sh .

ENTRYPOINT /tmp/entrypoint.sh
