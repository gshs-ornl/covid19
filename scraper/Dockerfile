FROM python:3.8
LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.0" \
  description="Provides the Scraper images for retrieving county-level \
COVID-19 confirmed cases"

WORKDIR /tmp

ENV PYTHONOPTIMIZE True
ENV CHROME_DRIVER_VERSION 80.0.3987.106 

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

# install dependencies
RUN apt-get update -qqy && apt-get install -y build-essential && \
      apt-get install libnss3 libgconf-2-4 -y && \
      apt-get install unzip postgresql-client -y && \
      wget -q "$CHROME_DRIVER_URL/$CHROME_DRIVER_VERSION/$CHROME_ZIP_FILE" && \
      unzip $CHROME_ZIP_FILE && rm $CHROME_ZIP_FILE && \
      mv /tmp/chromedriver /usr/local/bin && \
      apt-get -y install xvfb gtk2-engines-pixbuf xfonts-cyrillic \
        xfonts-100dpi xfonts-75dpi xfonts-base xfonts-scalable libfontconfig

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

# cleanup
RUN rm /etc/apt/sources.list.d/google-chrome.list && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/*
