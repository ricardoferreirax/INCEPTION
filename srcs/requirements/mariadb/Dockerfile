FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/mysqld /var/lib/mysql && chown -R mysql:mysql /run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql

COPY ./tools/init_mariadb.sh /usr/local/bin/init_mariadb.sh

RUN chmod +x /usr/local/bin/init_mariadb.sh

EXPOSE 3306

ENTRYPOINT ["init_mariadb.sh"]



# This Dockerfile builds the custom MariaDB image used by the MariaDB container.
# The image is built from Debian Bookworm and contains only the packages and files
# needed to run MariaDB inside the Inception Docker network.

# Update the Debian package index and install MariaDB.
#
# apt-get install -y mariadb-server: Installs the MariaDB server and its required 
#                                    dependencies. 
# This provides: - mariadbd, the MariaDB server daemon
#                - mariadb, the MariaDB client
#                - mariadb-install-db, used to create the initial system tables
#                - default MariaDB configuration files
#
# rm -rf /var/lib/apt/lists/*: Removes cached package lists after installation.
#   				           This keeps the final image smaller.

# Create the directories required by MariaDB.
#
# /run/mysqld: Runtime directory used by MariaDB for temporary process files.
#             Contain files such as: - mysqld.sock
#                                    - mysqld.pid
#
# /var/lib/mysql: Persistent database directory.
#                 This is where MariaDB stores: - internal system tables
#     										    - WordPress database files
#                                               - user and privilege metadata
#                                               - engine files
#
# chown -R mysql:mysql: MariaDB runs as the mysql user, not as root.
#                       Therefore, the mysql user must own these directories in order 
#                       to create, read, and modify database files.

# Copy the custom MariaDB initialization script into the image.
#
# The script is placed in /usr/local/bin because this directory is commonly used for PATH 
# executables that are not managed by the system package manager.
# This is because the script is custom and not part of the standard MariaDB installation, 
# so it should not be placed in a directory like /usr/bin or /usr/sbin which are typically 
# reserved for system-managed binaries.
#
# The script is responsible for: - checking that Docker secrets exist
#                                - reading the MariaDB passwords from Docker secrets
#                                - creating the MariaDB runtime and data directories if needed
#                                - generating the MariaDB configuration file inside /etc/mysql/mariadb.conf.d/
#   							 - init the MariaDB system tables if they do not exist
#   							 - creating the WordPress database if it does not already exist
#   							 - creating the WordPress database user if it does not already exist
#   							 - granting the WordPress user permissions only on the WordPress database
#   							 - setting the MariaDB root password
#   							 - starting MariaDB in the foreground

# Give execution permission to the initialization script.
#
# Without this permission, Docker would fail to start the container with a "Permission denied" error when 
# trying to execute the script.

# Document that the MariaDB container listens on TCP port 3306.
#
# EXPOSE does not publish the port to the host machine.
# It only documents the intended network port used by the container.
# In this project, WordPress connects to MariaDB through the Docker network using mariadb:3306.
# The port does not need to be exposed to the host machine because only the
# WordPress container needs to access MariaDB.

# Define the command executed when the container starts.
#
# Every time the container starts, this script prepares the MariaDB environment and finally replaces itself 
# with the MariaDB server process.