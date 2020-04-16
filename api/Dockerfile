FROM code.ornl.gov:4567/nset_covid19/covid19scrapers/base:latest

RUN apt-get update \
    && apt-get install -y -t unstable \
        ca-certificates \
        nginx \
        gettext-base \
        supervisor \
        uwsgi \
    && rm -rf /var/lib/apt/lists/*

#configuration configuration
COPY ./nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /spool/nginx /run/pid \
    && chmod -R 666 \
        /var/log/nginx \
        /etc/nginx \
        /var/run \
        /run \
        /run/pid \
        /spool/nginx

COPY ./uwsgi.ini /etc/uwsgi/apps-available/uwsgi.ini
#RUN ln -s /etc/uwsgi/apps-available/uwsgi.ini /etc/uwsgi/apps-enabled/uwsgi.ini
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /tmp

# copy over required files and install requirements
COPY ./requirements.txt .
RUN pip install -r requirements.txt
COPY ./es_app/* ./es_app/es_app/
COPY ./setup.py ./es_app/setup.py

# install package implementing api
RUN pip install ./es_app


WORKDIR /opt/repo

COPY ./es_app/app.py .
RUN chmod +x app.py

EXPOSE 8888

CMD ["/usr/bin/supervisord"]
