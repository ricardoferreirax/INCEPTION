#!/bin/bash

# stop the script if a command fails (-e) or if an undefined variable is used (-u)
set -eu

# define the MDB: persistent dir (where DB files are stored), the runtime dir with unix socket
# (used for local communication), MDB config file, and the init marker used to identify if the database was already configured.
MARIADB_DATA_DIR="/var/lib/mysql"
MARIADB_RUN_DIR="/run/mysqld"
MARIADB_SOCKET="$MARIADB_RUN_DIR/mysqld.sock"
MARIADB_CONFIG_FILE="/etc/mysql/mariadb.conf.d/docker.cnf"
MARIADB_INIT_FILE="$MARIADB_DATA_DIR/.mariadb_ready"

# check if the required docker secrets exist and read the DB passwords.
if [ -f /run/secrets/db_password ] && [ -f /run/secrets/db_root_password ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password)
    DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
else
    echo "[ERROR] >> Required database secrets not found."
    exit 1
fi

# create the runtime and the persistent database directories.
mkdir -p "$MARIADB_RUN_DIR" "$MARIADB_DATA_DIR"

# MDB runs as the mysql user, so it needs ownership of these directories.
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

# check if MDB has already been initialized, preventing users and database from being recreated.
if [ ! -f "$MARIADB_INIT_FILE" ]; then
    echo "[MARIADB] >> No initialization file found! Intializing MariaDB database..."
    echo "[MARIADB] >> Starting temporary MariaDB server in the background..."
	# run MDB as the mysql system user instead of root
    # use the persistent dir to store the database files
    # create the socket used by the initialization commands.
    # disable tcp connections and run the server in the background
    mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET" --skip-networking &
	
	# pid of the last process started in the background.
    MARIADB_PID=$!
    echo "[MARIADB] >> Temporary MariaDB PID: $MARIADB_PID"

    echo "[MARIADB] >> Trying to connect to the temporary MariaDB server..."
    # try a simple query (SELECT 1) several times to verify MDB is ready to receive and execute SQL commands before continuing
    # if it succeeds, exit the loop, otherwise, wait one second before trying again.
    for i in {1..10}; do
        if mariadb --socket="$MARIADB_SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        echo "[MARIADB] >> Waiting for MariaDB..."
        sleep 1
    done

    # perform one final connection test. If MDB still can't execute a query, stop with an error.
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

    chown mysql:mysql "$MARIADB_INIT_FILE"

    echo "[MARIADB] >> Stop the temporary MariaDB server..."
    mariadb-admin --socket="$MARIADB_SOCKET" -u root -p"$DB_ROOT_PASSWORD" shutdown

	echo "[MARIADB] >> Wait until the temporary MariaDB process to stop..."
    wait "$MARIADB_PID"

    echo "[MARIADB] >> MariaDB initialization completed."
else
    echo "[MARIADB] >> Database already initialized. Skipping initialization."
fi

# start the real MDB server in the foreground.
echo "[MARIADB] >> Starting MariaDB server in foreground..."
echo "[MARIADB] >> Current Bash PID: $$"

# exec replaces the bash process with mariadbd, making MDB PID 1 inside the container. 
# docker can send signals directly to MDB, allowing it to shut down correctly while keeping 
# the container running in foreground.
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET"
