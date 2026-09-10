FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl/private /etc/nginx/ssl/certs /var/www/html

RUN openssl genrsa -out /etc/nginx/ssl/private/priv.key 4096 && openssl req -new -x509 -key \
	/etc/nginx/ssl/private/priv.key -days 365 -out /etc/nginx/ssl/certs/pub.crt -subj "/CN=static.42.fr"

COPY ./conf/nginx.conf /etc/nginx/nginx.conf

COPY ./tools/index.html /var/www/html/index.html

RUN chown -R www-data:www-data /var/www/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]
