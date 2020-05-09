FROM python:3.8
LABEL maintainer="Joshua N. Grant <grantjn@ornl.gov>" \
  version="0.1.6" \
  description="Provides the base image for retrieving country-level \
  state-level, county-level COVID-19 asssociated data."

WORKDIR /tmp

ENV PYTHONOPTIMIZE True
ENV CHROME_DRIVER_VERSION 80.0.3987.106 
ENV R_VERSION 4.0.0
ENV R_LIB /usr/lib/R/site-library
ENV OUTPUT_DIR /tmp/output
ENV INPUT_DIR /tmp/input
ENV CLEAN_DIR /tmp/clean
ENV PIC_DIR /tmp/screenshots
ENV R_HOME /usr/lib/R
ENV R_SOURCE /usr/local/src/R
# Commenting out until we move to using the releases from github
#ENV COVIDR_VERS 0.1.16
#ENV COVIDR_URL https://github.com/nset-ornl/covidR/releases/download
# setup the output directory
RUN mkdir -p $OUTPUT_DIR $INPUT_DIR $CLEAN_DIR $PIC_DIR

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
    proj-bin postgresql-client git make tesseract-ocr autoconf-archive \
    libtiff5 libtiff5-dev libpng16-16 libpng-dev zlib1g zlib1g-dev \
    leptonica-progs libleptonica-dev libudunits2-0 libudunits2-data \
    libudunits2-dev gdal-bin libgdal-dev libproj-dev gfortran-multilib \
    libpcre2-32-0 libpcre2-dev && \
    apt-get autoremove


# confirm tesseract version
RUN set -eux && tesseract --version

# update apt source to point to the newest version of R
RUN echo "deb http://http.debian.net/debian sid main" > \
      /etc/apt/sources.list.d/debian-unstable.list && \
      echo 'APT::Default-Release "testing";' > /etc/apt/apt.conf.d/default 

# install R
RUN mkdir -p $R_SOURCE && cd $R_SOURCE && \
	wget https://cran.r-project.org/src/base/R-4/R-${R_VERSION}.tar.gz && \
	tar -zxvf R-${R_VERSION}.tar.gz && \
	cd R-${R_VERSION} && \
	CFLAGS="-g -O2 -fstack-protector-strong -D_DEFAULT_SOURCE -D__USE_MISC" \
	CXXFLAGS="-g -O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -D__MUSL__" \
	./configure --prefix=/usr \
	            --sysconfdir=/etc/R \
							--localstatedir=/var \
							--enable-memory-profiling \
							--enable-R-shlib \
	            --without-x && \
	make && make install && \
	cd src/nmath/standalone && make && make install && \
	rm -rf $R_SOURCE

# Configure R
RUN set -eux && echo "R_LIBS_SITE='/usr/lib/R/library'" >> \
      /usr/lib/R/etc/Renviron && \
	echo 'options(repos = c(CRAN = "https://cloud.r-project.org/"))' >> \
		/usr/lib/R/etc/Rprofile.site && \
		mkdir -p /etc/R && \
		ln -s /usr/lib/R/etc/* /etc/R/ && \
		mkdir -p /usr/lib/R/library && \
    wget "https://gist.githubusercontent.com/sempervent/4635569b9544949f4676b1fad8950956/raw/5919f0fc8150392882075e58a407990de66300f1/loadPackages.R"  >> /usr/lib/R/etc/Renviron && \
    ls -lash /usr/lib/R/etc/


RUN set -eux && \
      R --slave -e 'Sys.setenv(LANG="en_US.UTF-8")' && \
      R --slave -e 'Sys.setenv(LC_ALL="en_US.UTF-8")' && \
      cat /usr/lib/R/etc/Rprofile.site && \
      echo 'source("/usr/lib/R/etc/Rprofile.site")' >> /etc/littler.r

RUN set -eux && R --version

RUN apt-get update -qqy && apt-get install -t unstable -y \
        --no-install-recommends libgcc-8-dev
      #littler r-cran-littler  && \
      #ln -s $R_LIB/littler/examples/install.r /usr/local/bin/install.r && \
      #ln -s $R_LIB/littler/examples/install2.r /usr/local/bin/install2.r && \
      #ln -s $R_LIB/littler/examples/installGithub.r \
        #/usr/local/bin/installGithub.R 

# install tippecanoe
RUN set -eux && git clone https://github.com/mapbox/tippecanoe.git && \
      cd tippecanoe && make -j && make install

# set default database env files
ENV DB_HOST db
ENV DB_DB covidb
ENV DB_PORT 5432

# install python dependencies
COPY requirements.txt .
RUN set -eux && pip install --upgrade pip && \
        pip install --no-cache-dir -r requirements.txt

# install R packages
#RUN $R_LIB/littler/examples/install.r \
      #-r https://cloud.r-project.org docopt RPostgres data.table \
      #magrittr leaflet tidyverse rvest sp sf stringr jsonlite rebus lubridate \
      #anytime snakecase remotes readxl zip rgdal tidycensus stringr \
      #googlesheets4
COPY install_reqs.R /tmp/install_reqs.R
RUN Rscript /tmp/install_reqs.R

#RUN R -e "install.packages('dplyr', repos = 'https://cloud.r-project.org')"
#RUN R -e "devtools::install_github('tidyverse/googlesheets4')"

# install our python package
COPY setup.py .
COPY cvpy ./cvpy
RUN set -eux && python setup.py install --prefix=/usr/local

# install our R package
COPY covidR.tar.gz .
#RUN install.r covidR.tar.gz
RUN set -eux R --slave -e \
      'install.packages("/tmp/covidR.tar.gz", repos = NULL, type = "source")'

# cleanup
RUN rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
      rm -rf /tmp/downloaded_packages/ /tmp/*.rds && \
      rm covidR.tar.gz && rm -rf /tmp/tippecanoe
