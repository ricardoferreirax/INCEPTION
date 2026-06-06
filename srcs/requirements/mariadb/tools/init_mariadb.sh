#!/bin/bash

set -e

MARIADB_DATA_DIR="/var/lib/mysql"
MARIADB_RUN_DIR="/run/mysqld"
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"
MARIADB_CONFIG_FILE="/etc/mysql/mariadb.conf.d/docker.cnf"

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

if [ -z "$MDB_DATABASE" ] || [ -z "$MDB_USER" ]; then
	echo "[ERROR] >> Required environment variables are missing."
	exit 1
fi

mkdir -p "$MARIADB_RUN_DIR"
mkdir -p "$MARIADB_DATA_DIR"
mkdir -p /etc/mysql/mariadb.conf.d

chown -R mysql:mysql "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

cat > "$MARIADB_CONFIG_FILE" << EOF
[mysqld]
bind-address=0.0.0.0
port=3306
datadir=${MARIADB_DATA_DIR}
socket=${MARIADB_SOCKET}
skip-networking=0
EOF

if [ -d "$MARIADB_DATA_DIR/mysql" ]; then
	echo "[MARIADB] >> MariaDB system tables already exist."
	echo "[MARIADB] >> Skipping system table installation."
else
	echo "[MARIADB] >> MariaDB system tables not found."
	echo "[MARIADB] >> Installing MariaDB system tables..."
	mariadb-install-db --user=mysql --datadir="$MARIADB_DATA_DIR"
fi

echo "[MARIADB] >> Starting temporary MariaDB server..."
mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" &

until mariadb --socket="$MARIADB_SOCKET" -e "SELECT 1" >/dev/null 2>&1
do
	echo "[MARIADB] >> Waiting for MariaDB server..."
	sleep 1
done

echo "[MARIADB] >> Creating database and user if needed..."
mariadb --socket="$MARIADB_SOCKET" -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

echo "[MARIADB] >> Stopping temporary MariaDB server..."
mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown

echo "[MARIADB] >> Starting MariaDB..."
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET"