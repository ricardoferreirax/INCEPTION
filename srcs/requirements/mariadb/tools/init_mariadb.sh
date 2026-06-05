#!/bin/bash

# Stop the script if any command fails. Prevents MariaDB from starting with a broken or incomplete configuration.
set -e

# Define the path where MariaDB stores its database files. This directory is mounted to the MariaDB volume in docker-compose.yml.
DATADIR="/var/lib/mysql"

# Define the temporary SQL file that will be used during the first MariaDB startup.
# This file will contain SQL commands to create the database, user, privileges, and root password.
INIT_FILE="/tmp/mariadb_init.sql"

# Reads the passwords from the Docker secrets.
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

# Create the runtime directory used by MariaDB. MariaDB needs this directory for files such as the socket and PID file.
mkdir -p /run/mysqld

# Give ownership of /run/mysqld and /var/lib/mysql to the mysql user and group.
# MariaDB runs as the mysql user, so it needs permission to write to these directories.
chown -R mysql:mysql /run/mysqld "$DATADIR"

# Check if the internal MariaDB system database directory does not exist.
# If /var/lib/mysql/mysql does not exist, MariaDB has not been initialized yet.
# This block must only run on the first container startup.
if [ ! -d "$DATADIR/mysql" ]; then
	echo "Installing MariaDB system tables..."

	# Initialize the MariaDB data directory. This creates the internal system tables needed by MariaDB.
	# Examples: mysql.user, mysql.db, privilege tables, system metadata.
	# --user=mysql makes the created files belong to the mysql user. | --datadir tells MariaDB where to create the database files.
	mariadb-install-db --user=mysql --datadir="$DATADIR"
fi

echo "Creating MariaDB initialization file..."

# Create a temporary SQL file.
# CREATE DATABASE IF NOT EXISTS: Creates the WordPress database if it does not already exist.
# CREATE USER IF NOT EXISTS: Creates the MariaDB user used by WordPress. The '%' host means this user can 
# 							 connect from other containers in the Docker network.
# GRANT ALL PRIVILEGES: Gives the WordPress database user full permissions on the WordPress database only.
# ALTER USER: Sets the root password for root@localhost.
# FLUSH PRIVILEGES: Reloads privilege tables so the changes are applied immediately.
cat > "$INIT_FILE" << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

echo "Starting MariaDB with init file..."

# Start the MariaDB server.
# --user=mysql makes MariaDB run as the mysql user instead of root. | --datadir points MariaDB to the persistent database directory.
# --init-file executes the SQL file once during startup.
# exec replaces the shell script process with mysqld. This is important because mysqld becomes PID 1 inside the container.
exec mysqld --user=mysql --datadir="$DATADIR" --init-file="$INIT_FILE"
