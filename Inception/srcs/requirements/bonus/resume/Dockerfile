FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/sites-enabled/default

COPY conf/default.conf /etc/nginx/conf.d/

COPY ./srcs/ /var/www/static

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
