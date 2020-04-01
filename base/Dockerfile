FROM python:3.8
LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides the Scraper images for retrieving county-level \
COVID-19 confirmed cases"

WORKDIR /tmp

ENV PYTHONOPTIMIZE True
ENV CHROME_DRIVER_VERSION 80.0.3987.106 
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV R_BASE_VERSION 3.6.3
ENV R_LIB /usr/lib/R/site-library
ENV OUTPUT_DIR /tmp/output
ENV R_HOME /usr/lib/R
ENV COVIDR_VERS 0.1.1
ENV COVIDR_URL https://github.com/nset-ornl/covidR/releases/download

# setup the output directory
RUN mkdir $OUTPUT_DIR

# install dependencies
RUN apt-get update -yqq && apt-get -y install --no-install-recommends \
    xvfb gtk2-engines-pixbuf xfonts-cyrillic xfonts-100dpi xfonts-75dpi \
    xfonts-base xfonts-scalable libfontconfig ed less locales vim-tiny \
    wget ca-certificates fonts-texgyre libnss3 libgconf-2-4 \
    unzip postgresql-client libv8-dev libmagick++-dev libudunits2-dev \
    libgdal-dev gdal-bin libgeos++-dev libgeos-3.7.1 libproj-dev \
    proj-bin 

# install R
RUN echo "deb http://http.debian.net/debian sid main" > \
      /etc/apt/sources.list.d/debian-unstable.list && \
      echo 'APT::Default-Release "testing";' > /etc/apt/apt.conf.d/default

RUN apt-get update -qqy && apt-get install -t unstable -y \
        --no-install-recommends littler r-cran-littler \
        r-base=${R_BASE_VERSION}-* r-base-dev=${R_BASE_VERSION}-* \
        r-recommended=${R_BASE_VERSION}-* && \
      ln -s $R_LIB/littler/examples/install.r /usr/local/bin/install.r && \
      ln -s $R_LIB/littler/examples/install2.r /usr/local/bin/install2.r && \
      ln -s $R_LIB/littler/examples/installGithub.r \
        /usr/local/bin/installGithub.R 


# install python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
        pip install --no-cache-dir -r requirements.txt

# install our package
COPY setup.py .
COPY cvpy ./cvpy
RUN python setup.py install --prefix=/usr/local


# install R packages
RUN install.r docopt RPostgres data.table magrittr leaflet tidyverse rvest sp \
      sf stringr jsonlite rebus lubridate  \
      snakecase remotes readxl
# install covidR
# saving below for our web releases
#RUN wget $COVID_URL/$COVID_VERS/covidR_$COVID_VERS.tar.gz && \
      #install.r covidR_$COVID_VERS.tar.gz
COPY covidR.tar.gz .
RUN install.r covidR.tar.gz

# cleanup
RUN rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
      rm -rf /tmp/downloaded_packages/ /tmp/*.rds && \
      rm covidR.tar.gz
