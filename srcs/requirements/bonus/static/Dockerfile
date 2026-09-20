FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

# copy the static website files.
COPY ./tools/index.html /var/www/html/index.html
COPY ./tools/style.css /var/www/html/style.css
COPY ./tools/script.js /var/www/html/script.js

# copy the initialization script.
COPY ./tools/init_static.sh /usr/local/bin/init_static.sh

# give execution permission to the initialization script.
RUN chmod +x /usr/local/bin/init_static.sh

# give the NGINX user ownership of the static website files.
RUN chown -R www-data:www-data /var/www/html

# run the initialization script when the container starts.
ENTRYPOINT ["init_static.sh"]
