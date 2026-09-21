#!/bin/bash

# stop the script if a command fails (-e) or if an undefined variable is used (-u)
set -eu

# define MDB persistent dir (where DB files are stored), the runtime dir with unix socket,
# MDB config file, and the init marker used to identify if the database was already configured.
MARIADB_DATA_DIR="/var/lib/mysql"
MARIADB_RUN_DIR="/run/mysqld"
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"
MARIADB_CONFIG_FILE="/etc/mysql/mariadb.conf.d/docker.cnf"
MARIADB_INIT_FILE="$MARIADB_DATA_DIR/.mariadb_ready"

echo "[MARIADB] >> Checking if required Docker secrets exist..."
if [ -f /run/secrets/db_password ] && [ -f /run/secrets/db_root_password ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password)
    DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
else
    echo "[ERROR] >> Required database secrets not found."
    exit 1
fi

echo "[MARIADB] >> Creating persistent and runtime directories for MariaDB..."
mkdir -p "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

echo "[MARIADB] >> Giving mysql ownership of the MariaDB persistent and runtime directories..."
chown -R mysql:mysql "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

echo "[MARIADB] >> Creating MariaDB configuration file..."
cat > "$MARIADB_CONFIG_FILE" << EOF
# applies the following options to the MDB server daemon.
[mysqld]

# listen for connections coming from other containers in the docker network
bind-address=0.0.0.0

port=${MDB_PORT}

# persistent directory containing the MDB database files
datadir=${MARIADB_DATA_DIR}

# unix socket used for local communication with the MDB server.
socket=${MARIADB_SOCKET}
EOF
echo "[MARIADB] >> MariaDB configuration created successfully."

echo "[MARIADB] >> Checking if MariaDB database is already initialized..."
if [ ! -f "$MARIADB_INIT_FILE" ]; then
    echo "[MARIADB] >> No initialization file found! Intializing MariaDB database..."

    echo "[MARIADB] >> Starting temporary MariaDB server in the background..."
    mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --skip-networking &

	echo "[MARIADB] >> MDB run as the mysql system user instead of root"
	echo "[MARIADB] >> MDB TCP connections disabled to prevent other containers from connecting to the temporary MDB server"
	echo "[MARIADB] >> MDB running in the background so the script can continue to execute initialization commands"
	
	# pid of the last process started in the background."
    MARIADB_PID=$!
    echo "[MARIADB] >> Temporary MariaDB PID: $MARIADB_PID"

    echo "[MARIADB] >> Trying to connect to the temporary MariaDB server..."
	echo "[MARIADB] >> Try a simple query to verify MDB is ready to receive and execute SQL commands..."
    for i in {1..10}; do
        if mariadb --socket="$MARIADB_SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
		echo "[MARIADB] >> Temporary MariaDB server is not ready yet. Waiting for 1 second before trying again..."
        sleep 1
    done

	echo "[MARIADB] >> Performing one final connection test to the temporary MariaDB server..."
    if ! mariadb --socket="$MARIADB_SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1; then
        echo "[ERROR] >> Temporary MariaDB server failed to become ready."
        exit 1
    fi
	echo "[MARIADB] >> Temporary MariaDB server is ready to accept connections."

    echo "[MARIADB] >> Configuring the WordPress database and database user..."
    mariadb --socket="$MARIADB_SOCKET" -u root << EOF
CREATE DATABASE IF NOT EXISTS \`wordpress\`;

-- '%' host allows this user to connect from another container through the docker network.
CREATE USER IF NOT EXISTS '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

-- is used to set the password for the user to the one specified in the Docker secret.
ALTER USER '${MDB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

-- grants the user full access to the wordpress database, but not to other databases.
GRANT ALL PRIVILEGES ON \`wordpress\`.* TO '${MDB_USER}'@'%';

-- is used to set the password for the root user to the one specified in the Docker secret.
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

-- reloads the privilege information so that the changes take effect immediately.
FLUSH PRIVILEGES;
EOF
    echo "[MARIADB] >> Database and user configuration completed."

    echo "[MARIADB] >> Creating initialization marker inside the persistent database directory..."
    touch "$MARIADB_INIT_FILE"

	echo "[MARIADB] >> Giving mysql ownership of the MariaDB initialization marker..."
    chown mysql:mysql "$MARIADB_INIT_FILE"

    echo "[MARIADB] >> Stop the temporary MariaDB server..."
    mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"$DB_ROOT_PASSWORD" shutdown

	echo "[MARIADB] >> Wait until the temporary MariaDB process to stop..."
    wait "$MARIADB_PID"

    echo "[MARIADB] >> MariaDB initialization completed."
else
    echo "[MARIADB] >> Database already initialized. Skipping initialization."
fi

echo "[MARIADB] >> Starting MariaDB server in foreground..."
echo "[MARIADB] >> Current Bash PID: $$"
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET"
