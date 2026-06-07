#!/bin/bash

# Tells Bash to stop the script whenever a command returns a non-zero exit status.
set -e

# Persistent MariaDB data directory. Contains system tables, user databases, metadata and transaction logs.
MARIADB_DATA_DIR="/var/lib/mysql"

# Runtime directory for the MariaDB temporary runtime files: socket (mysqld.sock) and PID file (mysqld.pid).
MARIADB_RUN_DIR="/run/mysqld"

# Directory where MariaDB configuration files are stored. Here, MariaDB loads all the configuration files.
MARIADB_CONFIG_DIR="/etc/mysql/mariadb.conf.d"

# Custom configuration file created by this script. Will contain the necessary settings for MariaDB.
MARIADB_CONFIG_FILE="$MARIADB_CONFIG_DIR/docker.cnf"

# Local Unix socket used by MariaDB client commands inside the container. 
# This file allows local communication between MariaDB clients and the MariaDB server without using TCP networking.
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"

# Marker used to detect whether the inception setup has already been completed.
MARIADB_INIT_FILE="$MARIADB_DATA_DIR/.mariadb_ready"

echo "[MARIADB] >> Verifying required Docker secrets..."
if [ -f /run/secrets/db_password ]; then
	DB_PASSWORD=$(cat /run/secrets/db_password)
else
	echo "[ERROR] >> db_password secret not found."
	exit 1
fi

if [ -f /run/secrets/db_root_password ]; then
	DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
else
	echo "[ERROR] >> db_root_password secret not found."
	exit 1
fi

echo "[MARIADB] >> Checking environment variables..."
if [ -z "$MDB_DATABASE" ] || [ -z "$MDB_USER" ]; then
	echo "[ERROR] >> MDB_DATABASE or MDB_USER is missing."
	exit 1
fi

# Creates required directories for MariaDB data and runtime files if they don't exist.
mkdir -p "$MARIADB_RUN_DIR"
mkdir -p "$MARIADB_DATA_DIR"
mkdir -p "$MARIADB_CONFIG_DIR"

# Changes the ownership of the MariaDB data and runtime directories to the mysql user and group. 
# MariaDB runs as the mysql user, so it must own theses directories to read and write into them.
chown -R mysql:mysql "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

# Creates the MariaDB configuration file with the required settings for the server to bind to all 
# interfaces to accept all incoming connections, listen on the default port 3306, and use the specified data directory and socket.
echo "[MARIADB] >> Creating MariaDB configuration file..."
cat > "$MARIADB_CONFIG_FILE" << EOF
[mysqld]
bind-address=0.0.0.0
port=3306
datadir=${MARIADB_DATA_DIR}
socket=${MARIADB_SOCKET}
EOF

# Checks if the MariaDB initialization marker file exists.  
if [ -f "$MARIADB_INIT_FILE" ]; then
	echo "[MARIADB] >> Existing MariaDB setup detected. Skipping initialization and reusing persisted data."
else
	echo "[MARIADB] >> No MariaDB initialization marker found. Preparing MariaDB data directory..."

	if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
		echo "[MARIADB] >> MariaDB system tables not found."

		echo "[MARIADB] >> Installing MariaDB internal system tables..."
		mariadb-install-db --user=mysql --datadir="$MARIADB_DATA_DIR"
	else
		echo "[MARIADB] >> MariaDB system tables already exist. Skipping system table installation."
	fi

	# Starts a temporary MariaDB server in background. The script continues executing while MariaDB runs. Stores the PID of the temporary server.
	echo "[MARIADB] >> Starting temporary MariaDB server for setup..."
	mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" &
	pid="$!"

	# Attempts to connect to the temporary MariaDB server to be ready to accept local connections. Repeatedly try to connect to the server using the 
	# mysql client with the root user and the specified socket. If the connection fails, it waits for 1 second and tries again until a successful connection is established.
	until mariadb --socket="$MARIADB_SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1
	do
		echo "[MARIADB] >> Waiting for MariaDB to accept local connections..."
		sleep 1
	done

	# Executes SQL commands to create the specified database, user, and privileges. Flush privileges to reload the grant tables in MariaDB, 
	# which is necessary to ensure that the new permissions are applied without needing to restart the server.
	echo "[MARIADB] >> Creating database, user and privileges..."
	mariadb --socket="$MARIADB_SOCKET" -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

	# Creates the MariaDB initialization marker file so future starts skip the initialization phase.
	echo "[MARIADB] >> Writing MariaDB initialization marker..."
	touch "$MARIADB_INIT_FILE"

	# Stops the temporary MariaDB server by sending a shutdown command through the mysql client. Ensures that the server is properly terminated before starting the final MariaDB instance.
	echo "[MARIADB] >> Stopping temporary MariaDB server..."
	mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown

	# Waits for the temporary MariaDB server process to fully exit. Avoids race conditions before starting the final MariaDB instance.
	wait "$pid" || true
fi

# Command exec replaces the shell process with mariadbd. As a result PID 1 = mariadbd
# This is the correct behaviour for Docker containers because Docker expects the main process to run as PID 1.
echo "[MARIADB] >> Starting MariaDB in foreground..."
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET"
