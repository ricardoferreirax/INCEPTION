FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/mysqld /var/lib/mysql && chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY ./tools/init_mariadb.sh /usr/local/bin/init_mariadb.sh

RUN chmod +x /usr/local/bin/init_mariadb.sh

ENTRYPOINT ["init_mariadb.sh"]
