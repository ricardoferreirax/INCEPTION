FROM debian:bookworm

RUN apt-get update && apt-get install -y php php-mysql curl ca-certificates && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

COPY ./tools/init_adminer.sh /usr/local/bin/init_adminer.sh

RUN chmod +x /usr/local/bin/init_adminer.sh

ENTRYPOINT ["init_adminer.sh"]
