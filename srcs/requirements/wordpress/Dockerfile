FROM debian:bookworm

RUN apt-get update && apt-get install -y php-fpm php-mysql php-curl php-zip \
	mariadb-client curl wget tar ca-certificates

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x /usr/local/bin/wp

RUN mkdir -p /run/php /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY 

RUN 

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT [""]
