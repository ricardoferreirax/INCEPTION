# This Dockerfile builds the MariaDB container image. The image is built from Debian Bookworm and 
# installs only MariaDB Server.
#
# During container startup: - MariaDB loads its custom configuration file
# 						    - Docker secrets are read by the initialization script
# 						    - the WordPress database is created (if it does not exist)
# 						    - the WordPress database user is created
# 							- the required privileges are granted
# 					        - MariaDB starts and listens on port 3306
#
# Database files are stored in /var/lib/mysql. This directory is connected to a Docker volume in 
# docker-compose.yml,ensuring data persistence even if the container is recreated.

FROM debian:bookworm

EXPOSE 3306

RUN apt-get update && apt-get install -y mariadb-server

RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init_mariadb.sh /bin/init_mariadb.sh

RUN chmod +x /bin/init_mariadb.sh

ENTRYPOINT ["/bin/init_mariadb.sh"]