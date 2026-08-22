FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx openssl \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/sites-enabled/default

RUN mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/sel-jari.key \
        -out    /etc/nginx/ssl/sel-jari.crt \
        -subj "/C=MA/ST=BENGUERIR/L=BENGUERIR/O=1337/OU=42/CN=sel-jari.42.fr"


COPY conf/default.conf /etc/nginx/conf.d/

ENTRYPOINT	[ "nginx", "-g", "daemon off;" ]
