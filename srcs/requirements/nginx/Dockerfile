FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

COPY ./conf/server.conf /tmp/server.conf
COPY ./conf/server-bonus.conf /tmp/server-bonus.conf

COPY ./tools/init_nginx.sh /usr/local/bin/init_nginx.sh

RUN chmod +x /usr/local/bin/init_nginx.sh

ENTRYPOINT ["init_nginx.sh"]
