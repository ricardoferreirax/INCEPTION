FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init_mariadb.sh /bin/init_mariadb.sh

RUN chmod +x /bin/init_mariadb.sh && mkdir -p /run/mysqld /var/lib/mysql \
	&& chown -R mysql:mysql /run/mysqld /var/lib/mysql

EXPOSE 3306

ENTRYPOINT ["/bin/init_mariadb.sh"]



# This Dockerfile is used to build the image for the MariaDB database container.
# Use Debian Bookworm as the base operating system for the image. Every instruction that follows will be 
# executed on top of this Debian filesystem. The image initially contains only the minimal Debian environment 
# and basic system utilities.

# First, we use RUN command which executes commands during image build time.
# This command is executed only during image creation, not every time a container starts.
# Downloads the latest package from Debian repositories, which allows Debian to know which packages are 
# available and where to download them, then, installs the MariaDB server package and all required dependencies.
# After this, the image contains: - mysqld (MariaDB server)
# 								  - mariadb client utilities
# 								  - mariadb-install-db
# 								  - default MariaDB configuration files

# The COPY command copies a file from the project directory into the image.
# From source: conf/50-server.cnf  to destination: /etc/mysql/mariadb.conf.d/50-server.cnf
# This file overrides part of MariaDB's default configuration, such as the bind-address, port, datadir, and socket 
# settings. By placing it in the mariadb.conf.d directory, MariaDB automatically loads it during startup.

# Copy the custom MariaDB initi script into the image.
# From source: tools/init_mariadb.sh  to destination: /bin/init_mariadb.sh.
# This script is responsible for: - reading Docker secrets
# 								  - initializing the database directory
# 								  - creating the WordPress database
# 								  - creating the WordPress database user
# 								  - setting the root password
# 								  - starting MariaDB
#
# The script will be executed when the container starts.
 
# > Add execute permission to the init script: chmod +x /bin/init_mariadb.sh .
# Without this permission Docker would fail with "Permission denied", when trying to execute the script.
# > Create directories required by MariaDB: mkdir -p /run/mysqld /var/lib/mysql .
# /run/mysqld stores the runtime files such as: mysqld.sock and mysqld.pid .
# /var/lib/mysql stores database files such as: system tables, user databases and transaction logs.
# The -p flag prevents errors if directories already exist.
# > Change ownership of the directories to mysql:mysql: chown -R mysql:mysql /run/mysqld /var/lib/mysql .
# Owner: mysql | Group: mysql .
# MariaDB runs as the mysql user. Therefore it must have permission to create and modify files inside these directories.

# This container provides a service on TCP port 3306. Port 3306 is the default MariaDB port.
# EXPOSE does NOT publish the port to the host machine. It only declares that the container expects to communicate 
# through this port. Other containers on the Docker network can connect to: mariadb:3306, because Docker provides internal DNS resolution.
#
# In the Inception project, WordPress connects to MariaDB through this port.

# For last, the ENTRYPOINT defines the command executed when the container starts.
# Every time Docker creates a container from this image, it automatically runs: /bin/init_mariadb.sh .
# The script then: - checks whether MariaDB has already been initialized
#                  - creates the database if necessary
#                  - creates the WordPress user
#                  - sets the root password
#                  - starts mysqld
