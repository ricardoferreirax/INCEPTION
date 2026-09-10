FROM debian:bookworm

RUN apt update && apt install -y nginx openssl  && mkdir -p /etc/nginx/ssl/private /etc/nginx/ssl/certs \
    /var/www/html && openssl genrsa -out /etc/nginx/ssl/private/priv.key 4096 && openssl req -new -x509 \
    -key /etc/nginx/ssl/private/priv.key -days 365 -out /etc/nginx/ssl/certs/pub.crt -subj "/CN=static.42.fr"

COPY ./conf/nginx.conf /etc/nginx/nginx.conf

COPY ./tools/index.html /var/www/html/index.html
COPY ./tools/styles.css /var/www/html/styles.css
COPY ./tools/script.js /var/www/html/script.js

ENTRYPOINT ["nginx"]

CMD ["-g", "daemon off;"]
