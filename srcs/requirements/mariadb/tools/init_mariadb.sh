#!/bin/bash

# This script is executed when the MariaDB container starts.
# Its responsibilities are:
# - read passwords from Docker secrets
# - initialize the MariaDB data directory if needed
# - create the WordPress database
# - create the WordPress database user
# - grant privileges to that user
# - start MariaDB in the foreground
#
# The script must be idempotent:
# it should initialize the database only the first time.
#

DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d "/var/lib/mysql/mysql" ]; then
	echo "Installing MariaDB for the first time..."
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

cat > /tmp/init.sql << EOF
CREATE DATABASE IF NOT EXISTS \`${MDB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MDB_DATABASE}\`.* TO '${MDB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

exec mariadbd --user=mysql --console --init-file=/tmp/init.sql