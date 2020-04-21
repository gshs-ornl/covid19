FROM rocker/shiny-verse:latest

LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides a shiny interface to comparing multiple data source \
streams"

USER root

ENV R_LIB /usr/lib/R/site-library
# set default database env files
ENV DB_HOST db
ENV DB_DB covidb
ENV DB_PORT 5432

# system libraries
RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
      sudo pandoc pandoc-citeproc libcurl4-gnutls-dev libcairo2-dev \
      libxt-dev libssl-dev libssh2-1-dev r-cran-littler postgresql-client \
      libgeos-3.7.1 gdal-bin libgdal-dev libproj-dev libudunits2-0 \
      libudunits2-dev && \
      ln -s $R_LIB/littler/examples/install.r /usr/local/bin/install.r && \
      #ln -s $R_LIB/littler/examples/install2.r /usr/local/bin/install2.r && \
      ln -s $R_LIB/littler/examples/installGithub.r \
        /usr/local/bin/installGithub.r

# force en_US.UTF-8 in R
RUN set -eux && \
      R --slave -e 'Sys.setenv(LANG="en_US.UTF-8")' && \
      R --slave -e 'Sys.setenv(LC_ALL="en_US.UTF-8")'

# install R packages
RUN install.r docopt RPostgres data.table magrittr leaflet sp sf data.table \
      leaflet stringr jsonlite rebus lubridate anytime snakecase remotes \
      readxl rgdal shiny shinydashboard glue DT plotly && \
      installGithub.r andrewsali/shinycssloaders

# copy over pgpass
COPY .pgpass /home/shiny
RUN chmod u-x,go-rwx /home/shiny/.pgpass

# copy the app to the image
COPY project.Rproj /srv/shiny-server/
COPY app.R /srv/shiny-server/
COPY fxns.R /srv/shiny-server/
COPY data /srv/shiny-server/data

# copy over entry command
COPY shiny_run.sh /usr/bin/shiny_run.sh

# allow permission for shiny user
RUN chown -R shiny:shiny /srv/shiny-server

USER shiny

EXPOSE 3838

# run the app
CMD ["/usr/bin/shiny_run.sh"]
