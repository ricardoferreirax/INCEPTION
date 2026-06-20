FROM debian:bookworm

RUN apt-get update && apt-get install -y php-fpm php-mysql mariadb-client curl \
	ca-certificates && rm -rf /var/lib/apt/lists/*

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p /var/www/html /run/php && chown -R www-data:www-data /var/www/html /run/php

COPY ./tools/init_wordpress.sh /usr/local/bin/init_wordpress.sh

RUN chmod +x /usr/local/bin/init_wordpress.sh

ENTRYPOINT ["init_wordpress.sh"]
