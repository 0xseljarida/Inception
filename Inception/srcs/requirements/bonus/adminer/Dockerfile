FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	php8.2-fpm \
	php8.2-mysql \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www2.conf

ADD --chmod=644 https://github.com/vrana/adminer/releases/download/v6.0.1/adminer-6.0.1-mysql-en.php /var/www/adminer/index.php

RUN chown -R www-data:www-data /var/www/adminer

CMD ["php-fpm8.2", "-F"]
