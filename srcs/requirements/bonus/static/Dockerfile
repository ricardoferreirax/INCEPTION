FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

COPY ./tools/index.html /var/www/html/index.html
COPY ./tools/style.css /var/www/html/style.css
COPY ./tools/script.js /var/www/html/script.js

COPY ./tools/init_static.sh /usr/local/bin/init_static.sh

RUN chmod +x /usr/local/bin/init_static.sh

RUN chown -R www-data:www-data /var/www/html

ENTRYPOINT ["init_static.sh"]
