#!/bin/bash

# Stop the script immediately if any command fails.
set -e

# MariaDB persistent data directory. This is where MariaDB stores system tables, databases and internal files.
MARIADB_DATA_DIR="/var/lib/mysql"

# Runtime directory used by MariaDB for temporary files such as the socket.
MARIADB_RUN_DIR="/run/mysqld"

# Unix socket used by the MariaDB client and server to communicate locally.
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"

# Custom MariaDB configuration file generated at container startup.
MARIADB_CONFIG_FILE="/etc/mysql/mariadb.conf.d/docker.cnf"

# Read the WordPress database password from Docker secrets if it exists, otherwise exit with an error.
if [ -f /run/secrets/db_password ]; then
	DB_PASSWORD=$(cat /run/secrets/db_password)
else
	echo "[ERROR] >> db_password secret not found."
	exit 1
fi

# Read the MariaDB root password from Docker secrets if it exists, otherwise exit with an error.
if [ -f /run/secrets/db_root_password ]; then
	DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
else
	echo "[ERROR] >> db_root_password secret not found."
	exit 1
fi

# Check required environment variables from .env file. If any of them is missing, exit with an error.
if [ -z "$MDB_DATABASE" ] || [ -z "$MDB_USER" ]; then
	echo "[ERROR] >> Required environment variables are missing."
	exit 1
fi

# Create required MariaDB directories
mkdir -p "$MARIADB_RUN_DIR"
mkdir -p "$MARIADB_DATA_DIR"
mkdir -p /etc/mysql/mariadb.conf.d

# Give ownership to the mysql user because MariaDB runs as mysql.
chown -R mysql:mysql "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

# Create MariaDB configuration.
cat > "$MARIADB_CONFIG_FILE" << EOF
[mysqld]
bind-address=0.0.0.0
port=3306
datadir=${MARIADB_DATA_DIR}
socket=${MARIADB_SOCKET}
skip-networking=0
EOF

# Install MariaDB system tables only if they do not already exist.
if [ -d "$MARIADB_DATA_DIR/mysql" ]; then
	echo "[MARIADB] >> MariaDB system tables already exist."
	echo "[MARIADB] >> Skipping system table installation."
else
	echo "[MARIADB] >> MariaDB system tables not found."
	echo "[MARIADB] >> Installing MariaDB system tables..."
	mariadb-install-db --user=mysql --datadir="$MARIADB_DATA_DIR"
fi

# Start a temporary MariaDB server so we can execute SQL commands.
echo "[MARIADB] >> Starting temporary MariaDB server..."
mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" &

# Wait until MariaDB is ready to accept connections.
until mariadb --socket="$MARIADB_SOCKET" -e "SELECT 1" >/dev/null 2>&1
do
	echo "[MARIADB] >> Waiting for MariaDB server..."
	sleep 1
done

# Create database, user, permissions and root password.
echo "[MARIADB] >> Creating database and user if needed..."
mariadb --socket="$MARIADB_SOCKET" -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# Stop temporary MariaDB server.
echo "[MARIADB] >> Stopping temporary MariaDB server..."
mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown

# Start MariaDB in foreground.
echo "[MARIADB] >> Starting MariaDB..."
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET"