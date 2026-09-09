#!/bin/bash

# stop the script immediately if any command fails and if an undefined variable is used
set -eu

MARIADB_DATA_DIR="/var/lib/mysql"
MARIADB_RUN_DIR="/run/mysqld"
MARIADB_CONFIG_DIR="/etc/mysql/mariadb.conf.d"
MARIADB_CONFIG_FILE="$MARIADB_CONFIG_DIR/docker.cnf"
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"
MARIADB_INIT_FILE="$MARIADB_DATA_DIR/.mariadb_ready"

if [ -f /run/secrets/db_password ] && [ -f /run/secrets/db_root_password ]; then
	DB_PASSWORD=$(cat /run/secrets/db_password)
	DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
else
	echo "[ERROR] >> Required database secrets not found."
	exit 1
fi

mkdir -p "$MARIADB_RUN_DIR"
mkdir -p "$MARIADB_DATA_DIR"
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
echo "[MARIADB] >> Configuration written to $MARIADB_CONFIG_FILE"

if [ -f "$MARIADB_INIT_FILE" ]; then
	echo "[MARIADB] >> Init marker found! Skip recreating database and users!"
else
	echo "[MARIADB] >> No initialization marker found! Database initialization is required."
	echo "[MARIADB] >> Start MariaDB server temporarily in background..."
	mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --skip-networking &
	# save the PID of temporary MariaDB process, we need it later to wait for the process to completely finish.
	MARIADB_PID=$!
	echo "[MARIADB] >> Temporary MariaDB PID: $MARIADB_PID"
	# initially we assume that MariaDB is not ready.
	MARIADB_READY=0
	echo "[MARIADB] >> Waiting for temporary server to accept connections..."
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

if [ "$MARIADB_READY" -ne 1 ]; then
	echo "[ERROR] >> Temporary MariaDB server failed to become ready."
	exit 1
fi

	echo "[MARIADB] >> Configuring database '${MDB_DATABASE}'..."
	echo "[MARIADB] >> Configuring database user '${MDB_USER}'..."
	mariadb --socket="$MARIADB_SOCKET" -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
	echo "[MARIADB] >> Database and user configuration completed successfully."

	echo "[MARIADB] >> Creating MariaDB initialization marker..."
	touch "$MARIADB_INIT_FILE"
	chown mysql:mysql "$MARIADB_INIT_FILE"

	echo "[MARIADB] >> Stopping temporary MariaDB server..."
	mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown
	# wait until the temporary server process has fully exited before starting the permanent MariaDB process.
	wait "$MARIADB_PID" || true

	echo "[MARIADB] >> MariaDB initialization completed."
fi

echo "[MARIADB] >> Starting MariaDB server in foreground..."
echo "[MARIADB] >> Listening on port $MDB_PORT"
echo "[MARIADB] >> Current Bash PID: $$"
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --port="$MDB_PORT"
