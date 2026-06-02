#!/bin/bash

DATADIR="/var/lib/mysql"
INIT_FILE="/tmp/mariadb_init.sql"

DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
	echo "Installing MariaDB system tables..."
	mariadb-install-db --user=mysql --datadir="$DATADIR"

	echo "Creating MariaDB initialization file..."

	cat > "$INIT_FILE" << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

	echo "MariaDB first-time configuration completed."
	echo "Starting MariaDB with init file..."
	exec mysqld --user=mysql --datadir="$DATADIR" --init-file="$INIT_FILE"
fi

echo "MariaDB already initialized."
echo "Starting MariaDB normally..."
exec mysqld --user=mysql --datadir="$DATADIR"