#!/bin/bash

# stop the script immediately if any command fails and if an undefined variable is used
set -eu

MARIADB_DATA_DIR="/var/lib/mysql"
MARIADB_RUN_DIR="/run/mysqld"
MARIADB_CONFIG_DIR="/etc/mysql/mariadb.conf.d"
MARIADB_CONFIG_FILE="$MARIADB_CONFIG_DIR/docker.cnf"
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"
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

# create the runtime dir if it doesn't already exist, MariaDB needs this to create its unix socket.
mkdir -p "$MARIADB_RUN_DIR"

# create the data dir if it doesn't already exist, the database files will be stored here.
mkdir -p "$MARIADB_DATA_DIR"

# create the MariaDB config dir
mkdir -p "$MARIADB_CONFIG_DIR"

chown -R mysql:mysql "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

echo "[MARIADB] >> Creating MariaDB configuration file..."

cat > "$MARIADB_CONFIG_FILE" << EOF
[mysqld]
bind-address=0.0.0.0
port=${MDB_PORT}
datadir=${MARIADB_DATA_DIR}
socket=${MARIADB_SOCKET}
EOF

# checks if the marker exists, prevents recreating the database and users every time the container restarts.
if [ -f "$MARIADB_INIT_FILE" ]; then
	echo "[MARIADB] >> Existing MariaDB setup detected. Skipping initialization."

else
	echo "[MARIADB] >> No initialization marker found. Preparing data directory..."

	# if the data directory is empty, we need to create the system tables and set up the database and users.
	if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
		echo "[MARIADB] >> Installing MariaDB system tables..."

		# initialize MariaDB's internal database structure.
		mariadb-install-db --user=mysql --datadir="$MARIADB_DATA_DIR"

	else
		echo "[MARIADB] >> MariaDB system tables already exist."

	fi

	echo "[MARIADB] >> Starting temporary MariaDB server..."

	# start a temporary MariaDB server in the background, this is required cause SQL commands can't be executed until MariaDB is running.
	mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --skip-networking &

	# save the PID of temporary MariaDB process, we need it later to wait for the process to completely finish.
	MARIADB_PID=$!

	echo "[MARIADB] >> Waiting for temporary MariaDB server..."

	# initially we assume that MariaDB is not ready.
	MARIADB_READY=0

	# try to connect up to 10 times, each failed attempt waits 1 second before trying again, so the maximum waiting time is 10 seconds.
	for i in {1..10}; do

		# SELECT 1 is a query used to check if MariaDB is ready to receive SQL commands.
		if mariadb --socket="$MARIADB_SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1
		then

			MARIADB_READY=1
			break

		fi

		echo "[MARIADB] >> Waiting for MariaDB..."
		sleep 1

	done

	# if MariaDB never became ready, stop the temporary process and exit with an error instead of waiting forever.
	if [ "$MARIADB_READY" -ne 1 ]; then
		echo "[ERROR] >> Temporary MariaDB server failed to start."

		kill "$MARIADB_PID" 2>/dev/null || true
		wait "$MARIADB_PID" 2>/dev/null || true

		exit 1

	fi

	echo "[MARIADB] >> Creating database, user and privileges..."

	# Connect locally as root and configure the database
	mariadb --socket="$MARIADB_SOCKET" -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

	echo "[MARIADB] >> Creating MariaDB initialization marker..."

	# create the marker only after all SQL initialization succeeded.
	touch "$MARIADB_INIT_FILE"

	chown mysql:mysql "$MARIADB_INIT_FILE"

	echo "[MARIADB] >> Stopping temporary MariaDB server..."

	# stop the temporary MariaDB server.
	mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown

	# wait until the temporary server process has fully exited before starting the permanent MariaDB process.
	wait "$MARIADB_PID" || true

	echo "[MARIADB] >> MariaDB initialization completed."

fi

echo "[MARIADB] >> Starting MariaDB in foreground..."

# start real MariaDB server, exec replaces the Bash script with mariadbd, this makes MariaDB PID 1 inside the container.
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --port="$MDB_PORT"
