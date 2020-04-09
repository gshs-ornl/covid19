FROM python:3.8
LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.5" \
  description="Provides the Scraper images for retrieving county-level \
COVID-19 confirmed cases"

WORKDIR /tmp

ENV PYTHONOPTIMIZE True
ENV CHROME_DRIVER_VERSION 80.0.3987.106 
ENV R_BASE_VERSION 3.6.3
ENV R_LIB /usr/lib/R/site-library
ENV OUTPUT_DIR /tmp/output
ENV INPUT_DIR /tmp/input
ENV CLEAN_DIR /tmp/clean
ENV R_HOME /usr/lib/R
# Commenting out until we move to using the releases from github
#ENV COVIDR_VERS 0.1.1
#ENV COVIDR_URL https://github.com/nset-ornl/covidR/releases/download
# setup the output directory
RUN mkdir -p $OUTPUT_DIR $INPUT_DIR $CLEAN_DIR

RUN apt-get update -yqq && apt-get -yqq install --no-install-recommends \
      locales && \
    sed -i 's/^E *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen && echo "export LC_ALL=en_US.UTF-8" >> /root/.bashrc && \
    echo "export LANG=en_US.UTF-8" >> /root/.bashrc && \
    echo "export LANGUAGE=en_US.UTF-8" >> /root/.bashrc && \
    echo "export LC_ALL=en_US.UTF-8" >> /root/.bashrc

# install dependencies
RUN apt-get update -yqq && apt-get -yqq install --no-install-recommends \
    xvfb gtk2-engines-pixbuf xfonts-cyrillic xfonts-100dpi xfonts-75dpi \
    xfonts-base xfonts-scalable libfontconfig ed less locales vim-tiny \
    wget ca-certificates fonts-texgyre libnss3 libgconf-2-4 \
    unzip postgresql-client libv8-dev libmagick++-dev libudunits2-dev \
    libgdal-dev gdal-bin libgeos++-dev libgeos-3.7.1 libproj-dev \
    proj-bin postgresql-client git make tesseract-ocr

# update apt source to point to the newest version of R
RUN echo "deb http://http.debian.net/debian sid main" > \
      /etc/apt/sources.list.d/debian-unstable.list && \
      echo 'APT::Default-Release "testing";' > /etc/apt/apt.conf.d/default

# install R
RUN apt-get update -qqy && apt-get install -t unstable -y \
        --no-install-recommends littler r-cran-littler \
        r-base=${R_BASE_VERSION}-* r-base-dev=${R_BASE_VERSION}-* \
        r-recommended=${R_BASE_VERSION}-* && \
      ln -s $R_LIB/littler/examples/install.r /usr/local/bin/install.r && \
      ln -s $R_LIB/littler/examples/install2.r /usr/local/bin/install2.r && \
      ln -s $R_LIB/littler/examples/installGithub.r \
        /usr/local/bin/installGithub.R 

# install tippecanoe
RUN set -eux && git clone https://github.com/mapbox/tippecanoe.git && \
      cd tippecanoe && make -j && make install


# force en_US.UTF-8 in R
RUN set -eux && \
      R --slave -e 'Sys.setenv(LANG="en_US.UTF-8")' && \
      R --slave -e 'Sys.setenv(LC_ALL="en_US.UTF-8")'

# set default database env files
ENV DB_HOST db
ENV DB_DB covidb
ENV DB_PORT 5432
# install python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
        pip install --no-cache-dir -r requirements.txt

# install R packages
RUN install.r docopt RPostgres data.table magrittr leaflet tidyverse rvest sp \
      sf stringr jsonlite rebus lubridate anytime snakecase remotes readxl  

# install our python package
COPY setup.py .
COPY cvpy ./cvpy
RUN python setup.py install --prefix=/usr/local

# install our R package
COPY covidR.tar.gz .
RUN install.r covidR.tar.gz

# cleanup
RUN rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
      rm -rf /tmp/downloaded_packages/ /tmp/*.rds && \
      rm covidR.tar.gz && rm -rf /tmp/tippecanoe

