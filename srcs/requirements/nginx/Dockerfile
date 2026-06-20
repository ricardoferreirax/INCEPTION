FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

COPY ./tools/init_nginx.sh /usr/local/bin/init_nginx.sh

RUN chmod +x /usr/local/bin/init_nginx.sh

ENTRYPOINT ["init_nginx.sh"]
