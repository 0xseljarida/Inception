FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	php8.2-fpm \
	php8.2-mysql \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www-listen.conf

ADD --chmod=755 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar /usr/local/bin/wp

WORKDIR /var/www/html

RUN wp core download --allow-root && chown -R www-data:www-data /var/www/html

COPY --chmod=755 tools/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm8.2", "-F"]
