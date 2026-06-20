#!/bin/bash

set -e

WORDPRESS_DIR="/var/www/html"
WP_CONFIG_FILE="$WORDPRESS_DIR/wp-config.php"
PHP_FPM_RUN_DIR="/run/php"
PHP_FPM_CONFIG_DIR="/etc/php/8.2/fpm/pool.d"
PHP_FPM_CONFIG_FILE="$PHP_FPM_CONFIG_DIR/www.conf"

echo "[WORDPRESS] >> Verifying required Docker secrets..."
if [ -f /run/secrets/db_password ]; then
	DB_PASSWORD=$(cat /run/secrets/db_password)
else
	echo "[ERROR] >> db_password secret not found."
	exit 1
fi

if [ -f /run/secrets/wp_admin_password ]; then
	WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
else
	echo "[ERROR] >> wp_admin_password secret not found."
	exit 1
fi

if [ -f /run/secrets/wp_user_password ]; then
	WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
else
	echo "[ERROR] >> wp_user_password secret not found."
	exit 1
fi

echo "[WORDPRESS] >> Checking required environment variables..."
if [ -z "$MDB_HOST" ] || [ -z "$MDB_PORT" ] || [ -z "$MDB_DATABASE" ] || [ -z "$MDB_USER" ] || \
	[ -z "$WP_URL" ] || [ -z "$WP_TITLE" ] || [ -z "$WP_ADMIN_USER" ] || \
	[ -z "$WP_ADMIN_EMAIL" ] || [ -z "$WP_USER" ] || [ -z "$WP_USER_EMAIL" ] || \
	[ -z "$WP_USER_ROLE" ] || [ -z "$PHP_FPM_PORT" ];
then
	echo "[ERROR] >> Required environment variables are missing."
	exit 1
fi

if ! [[ "$MDB_PORT" =~ ^[0-9]+$ ]] || ! [[ "$PHP_FPM_PORT" =~ ^[0-9]+$ ]]; then
	echo "[ERROR] >> MDB_PORT and PHP_FPM_PORT must be numbers."
	exit 1
fi

mkdir -p "$WORDPRESS_DIR"
mkdir -p "$PHP_FPM_RUN_DIR"
mkdir -p "$PHP_FPM_CONFIG_DIR"

chown -R www-data:www-data "$WORDPRESS_DIR" "$PHP_FPM_RUN_DIR"

# Creates the PHP-FPM pool configuration file with the necessary settings for the www pool. The configuration specifies 
# that the pool listens on all interfaces on the specified port, runs as the www-data user and group, and uses dynamic 
# process management with defined limits for child processes.
echo "[WORDPRESS] >> Creating PHP-FPM configuration file..."
cat > "$PHP_FPM_CONFIG_FILE" << EOF
[www]
user = www-data
group = www-data
listen = 0.0.0.0:${PHP_FPM_PORT}
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
clear_env = no
EOF

# Enter the WordPress directory to execute WP-CLI commands, which is a tool for managing WordPress installations.
cd "$WORDPRESS_DIR"

# Attempts to connect to the MariaDB server in a loop until it is ready to accept connections. 
# This ensures that the database is available before proceeding with WordPress installation.
echo "[WORDPRESS] >> Waiting for MariaDB..."
until mariadb -h "$MDB_HOST" -P "$MDB_PORT" -u "$MDB_USER" -p"$DB_PASSWORD" "$MDB_DATABASE" -e "SELECT 1" >/dev/null 2>&1
do
	echo "[WORDPRESS] >> MariaDB is not ready yet..."
	sleep 2
done

if [ -f "$WP_CONFIG_FILE" ]; then
	echo "[WORDPRESS] >> Existing WordPress configuration detected."

	echo "[WORDPRESS] >> Updating database host configuration..."
	wp config set DB_HOST "${MDB_HOST}:${MDB_PORT}" --allow-root
else
	echo "[WORDPRESS] >> Downloading WordPress core files..."
	wp core download --allow-root

	echo "[WORDPRESS] >> Creating wp-config.php..."
	wp config create --dbname="$MDB_DATABASE" --dbuser="$MDB_USER" --dbpass="$DB_PASSWORD" --dbhost="${MDB_HOST}:${MDB_PORT}" --allow-root

	echo "[WORDPRESS] >> Installing WordPress site..."
	wp core install --url="$WP_URL" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root

	echo "[WORDPRESS] >> Creating additional WordPress user..."
	wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$WP_USER_PASSWORD" --role="$WP_USER_ROLE" --allow-root

	echo "[WORDPRESS] >> WordPress installation completed."
fi

echo "[WORDPRESS] >> Updating WordPress file ownership..."
chown -R www-data:www-data "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Starting PHP-FPM in foreground..."
exec php-fpm8.2 -F
