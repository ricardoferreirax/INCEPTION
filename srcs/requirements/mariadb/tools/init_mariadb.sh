#!/bin/bash

set -eu

MARIADB_DATA_DIR="/var/lib/mysql"
MARIADB_RUN_DIR="/run/mysqld"

# path where MariaDB configuration files are stored
MARIADB_CONFIG_DIR="/etc/mysql/mariadb.conf.d"

# config file created by this script
MARIADB_CONFIG_FILE="$MARIADB_CONFIG_DIR/docker.cnf"

# unix socket used to communicate with MariaDB locally.
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"

# file used to mark that the database was already initialized.
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


# create the MariaDB runtime directory if it does not exist.
mkdir -p "$MARIADB_RUN_DIR"

# create the MariaDB data directory if it does not exist.
mkdir -p "$MARIADB_DATA_DIR"

# create the MariaDB configuration directory if it does not exist.
mkdir -p "$MARIADB_CONFIG_DIR"

chown -R mysql:mysql "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

echo "[MARIADB] >> Creating MariaDB configuration file..."

# create the MariaDB server configuration file.
cat > "$MARIADB_CONFIG_FILE" << EOF
[mysqld]
bind-address=0.0.0.0
port=${MDB_PORT}
datadir=${MARIADB_DATA_DIR}
socket=${MARIADB_SOCKET}
EOF

# check if MariaDB was already initialized
if [ -f "$MARIADB_INIT_FILE" ]; then
	echo "[MARIADB] >> Existing MariaDB setup detected. Skipping initialization."
else
	echo "[MARIADB] >> No initialization marker found. Preparing data directory..."

	# check if the MariaDB system tables already exist.
	if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
		echo "[MARIADB] >> Installing MariaDB system tables..."
		
		mariadb-install-db --user=mysql --datadir="$MARIADB_DATA_DIR"  # Initialize the MariaDB data directory and system tables.
	else
		echo "[MARIADB] >> MariaDB system tables already exist."   # Do not recreate the system tables if they already exist.
	fi

	echo "[MARIADB] >> Starting temporary MariaDB server..."

	# Start MariaDB temporarily without network access.
	mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --skip-networking &

	MARIADB_PID=$!   # Save the PID of the temporary MariaDB process

	echo "[MARIADB] >> Waiting for temporary MariaDB server..."

	MARIADB_READY=0  # start with MariaDB marked as not ready

	# try for a maximum of 30 seconds to connect to MariaDB.
	for i in {1..30}; do

		# test if the temporary MariaDB server accepts local connections
		if mariadb --socket="$MARIADB_SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1 
		then
			MARIADB_READY=1  # Mark MariaDB as ready.
			break  # stop waiting because MariaDB is ready.
		fi

		# wait before trying the connection again.
		echo "[MARIADB] >> Waiting for MariaDB..."
		sleep 1
	done

	# check if MariaDB failed to start after all attempts.
	if [ "$MARIADB_READY" -ne 1 ]; then
		echo "[ERROR] >> Temporary MariaDB server failed to start."

		kill "$MARIADB_PID" 2>/dev/null || true    # stop the temporary process if it is still running.
		wait "$MARIADB_PID" 2>/dev/null || true    # wait for the temporary process to terminate.

		exit 1  # Stop the initialization script with an error.
	fi

	echo "[MARIADB] >> Creating database, user and privileges..."

	# connect as root through the local socket and execute the initialization SQL.
	mariadb --socket="$MARIADB_SOCKET" -u root << EOF

CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

	echo "[MARIADB] >> Creating MariaDB initialization marker..."

	# create a file indicating that initialization completed successfully.
	touch "$MARIADB_INIT_FILE"

	chown mysql:mysql "$MARIADB_INIT_FILE"

	echo "[MARIADB] >> Stopping temporary MariaDB server..."

	# stop the temporary MariaDB server.
	mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown

	wait "$MARIADB_PID" || true   # wait for the temporary MariaDB process to fully terminate.

	echo "[MARIADB] >> MariaDB initialization completed."
fi

echo "[MARIADB] >> Starting MariaDB in foreground..."

# replace the script with MariaDB so mariadbd becomes PID 1.
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --port="$MDB_PORT"
