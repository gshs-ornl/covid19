FROM python:3.8-buster

ENV HOME /opt/repo
ENV NGINX_VERSION 1.15.7-1~stretch

RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        nginx \
        gettext-base \
        supervisor \
        uwsgi \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --no-create-home nginx

#configuration configuration
COPY ./deployment/nginx.conf /etc/nginx/nginx.conf
#RUN rm /etc/nginx/conf.d/default.conf
RUN mkdir -p /spool/nginx /run/pid \
    && chmod -R 666 \
        /var/log/nginx \
        /etc/nginx \
        /var/run \
        /run \
        /run/pid \
        /spool/nginx
COPY ./deployment/uwsgi.ini /etc/uwsgi/apps-available/uwsgi.ini
RUN ln -s /etc/uwsgi/apps-available/uwsgi.ini /etc/uwsgi/apps-enabled/uwsgi.ini
COPY ./deployment/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./es_app ${HOME}/es_app
COPY ./requirements.txt ${HOME}
RUN chmod -R 777 ${HOME}
RUN pip install -r ${HOME}/requirements.txt

EXPOSE 8888 8888

CMD ["/usr/bin/supervisord"]
