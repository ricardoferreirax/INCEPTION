#!/bin/bash

# This script is executed automatically when the MariaDB container starts. Its purpose is to prepare 
# the MariaDB environment, initialize the database storage if necessary, create the WordPress database 
# and user, and finally start the MariaDB server. The script is executed through the Dockerfile entrypoint.
# This means that every time the container starts, Docker executes this script before launching MariaDB.

DATADIR="/var/lib/mysql"  # directory where MariaDB stores databases, tables, user accounts and internal system files
INIT_FILE="/tmp/mariadb_init.sql"  # defines the temporary SQL file that will be executed during MariaDB startup.
                                   # The SQL commands generated later in the script will be written to this file, which will be used to initialize the database on the first run.

# Docker automatically mounts secrets inside /run/secrets/ . The script reads passwords from Docker Secrets.
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld "$DATADIR"


# if the mysql directory does not exist in the data directory, it means that MariaDB has not been initialized yet.
# So, this block ensures that MariaDB is initialized only once when the container is first started.
if [ ! -d "$DATADIR/mysql" ]; then
	echo "Installing MariaDB system tables..."
	mariadb-install-db --user=mysql --datadir="$DATADIR"
fi

echo "Creating MariaDB initialization file..."

# Creates a temporary SQL file containing the commands required to configure the MariaDB database.
# Creates the WordPress database and the MariaDB user used by WordPress with the specified password,
# grant privileges to the WordPress user, sets the root password for the MariaDB server
# and finally forces MariaDB to reload the privilege tables to apply the changes.
cat > "$INIT_FILE" << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

echo "MariaDB configuration completed."
echo "Starting MariaDB server on port ${MDB_PORT}..."

# Starts the MariaDB server. The exec command replaces the current shell process with the MariaDB process.
# As a result PID 1 inside the container becomes mysqld. Runs MariaDB using mysql user instead of root, tells
# MariaDB where the database files are stored and instructs MariaDB to execute the SQL commands in the initialization 
#file during startup. This ensures that the database is properly configured before accepting connections.
exec mysqld --user=mysql --datadir="$DATADIR" --init-file="$INIT_FILE"