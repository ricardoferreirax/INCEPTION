# This Dockerfile builds the MariaDB container image. The image is built from Debian Bookworm and 
# installs MariaDB Server. During startup: - MariaDB configuration is loaded
#                                          - Docker secrets are read
#                                          - database and users are created
#                                          - MariaDB starts and listens on port 3306
#
# Copy the custom MariaDB configuration file. MariaDB automatically loads configuration files located
#  in /etc/mysql/mariadb.conf.d/  .
# Copy the initialization script into the container.
# Make the initialization script executable.
# Execute the initialization script when the container starts.

FROM debian:bookworm

EXPOSE 3306

RUN apt-get update && apt-get install -y mariadb-server

RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init_mariadb.sh /bin/init_mariadb.sh

RUN chmod +x /bin/init_mariadb.sh

ENTRYPOINT ["/bin/init_mariadb.sh"]