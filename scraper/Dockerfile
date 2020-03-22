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

# install dependencies
RUN apt-get -y install --no-recommends \
    xvfb gtk2-engines-pixbuf xfonts-cyrillic xfonts-100dpi xfonts-75dpi \
    xfonts-base xfonts-scalable libfontconfig ed less locales vim-tiny \
    wget ca-certificates fonts-texgyre

# install chrome
ARG CHROME_VERSION="google-chrome-stable"
ARG CHROME_PUBLIC_KEY="https://dl-ssl.google.com/linux/linux_signing_key.pub"
ARG CHROME_DRIVER_URL="https://chromedriver.storage.googleapis.com"
ARG CHROME_ZIP_FILE="chromedriver_linux64.zip"
RUN wget -q -O - "$CHROME_PUBLIC_KEY" | apt-key add - \
    && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | \
    tee /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update -qqy && \
    apt-get -qqy install ${CHROME_VERSION:-google-chrome-stable} && \

# install chrome and dependencies
RUN apt-get update -qqy && apt-get install -y build-essential && \
    apt-get install libnss3 libgconf-2-4 -y && \
    apt-get install unzip postgresql-client -y && \
    wget -q "$CHROME_DRIVER_URL/$CHROME_DRIVER_VERSION/$CHROME_ZIP_FILE" && \
    unzip $CHROME_ZIP_FILE && rm $CHROME_ZIP_FILE && \
    mv /tmp/chromedriver /usr/local/bin && \

# setup pgpass
COPY .pgpass /root/.pgpass
RUN chmod 0600 /root/.pgpass

# copy over data
COPY county_list.csv .
COPY url_list.csv .

# install python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
        pip install --no-cache-dir -r requirements.txt

# install our package
COPY setup.py .
COPY cvr ./cvr
RUN python setup.py install --prefix=/usr/local

# install R
RUN echo "deb http://http.debian.net/debian sid main" > \
      /etc/apt/sources.list.d/debian-unstable.list && \
      echo 'APT::Default-Release "testing:;' > /etc/apt/apt.conf.d/default

RUN apt-get update -qqy && apt-get install -t unstable -y \
        --no-install--recommends littler r-cran-littler \
        r-base=${R_BASE_VERSION}-* r-base-dev=${R_BASE_VERSION}-* \
        r-recommended=${R_BAS_VERSION}-* && \
      ln -s $R_LIB/littler/examples/install.r /usr/local/bin/install.r && \
      ln -s $R_LIB/littler/examples/install2.r /usr/local/bin/install2.r && \
      ln -s $R_LIB/littler/examples/installGithub.r \
        /usr/local/bin/installGithub.R 

# install R packages
RUN install.r docopt RPostgres data.table magrittr leaflet tidyverse rvest sp \
      sf maptools stringr jsonlite rebus lubridate shiny httr RSelenium \
      magick png snakecase V8 DBI
# install covidR
RUN installGithub.R nset-ornl/covidR

# cleanup
RUN rm /etc/apt/sources.list.d/google-chrome.list && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
      rm -rf /tmp/downloaded_packages/ /tmp/*.rds
