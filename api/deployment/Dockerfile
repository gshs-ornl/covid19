FROM python:3.8-stretch

RUN pip install --no-cache-dir --disable-pip-version-check uwsgi

ENV NGINX_VERSION 1.15.7-1~stretch

RUN set -x \
    && curl -O https://nginx.org/keys/nginx_signing.key \
    && apt-key add ./nginx_signing.key; \
    echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y \
        ca-certificates \
        nginx=${NGINX_VERSION} \
        gettext-base \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

#configuration configuration
RUN rm /etc/nginx/conf.d/default.conf \
    && echo "daemon off;" >> /etc/nginx/nginx.conf
COPY ./deployment/nginx.conf /etc/nginx/conf.d/
COPY ./deployment/uwsgi.ini /etc/uwsgi/
COPY ./deployment/supervisor.conf /etc/supervisor/conf.d/supervisord.conf

ENV LISTEN_PORT 8888
EXPOSE 8888 8888

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]