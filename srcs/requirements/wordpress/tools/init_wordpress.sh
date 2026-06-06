#!/bin/bash

set -e

WORDPRESS_DIR="/var/www/html"
WP_CONFIG_FILE="$WORDPRESS_DIR/wp-config.php"
PHP_FPM_CONFIG_FILE="/etc/php/8.2/fpm/pool.d/www.conf"

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

if [ -z "$MDB_HOST" ] || [ -z "$MDB_DATABASE" ] || [ -z "$MDB_USER" ] || [ -z "$WP_URL" ] || \
	[ -z "$WP_TITLE" ] || [ -z "$WP_ADMIN_USER" ] || [ -z "$WP_ADMIN_EMAIL" ] || \
	[ -z "$WP_USER" ] || [ -z "$WP_USER_EMAIL" ]
then
	echo "[ERROR] >> Required environment variables are missing."
	exit 1
fi

mkdir -p "$WORDPRESS_DIR"
mkdir -p /run/php

chown -R www-data:www-data "$WORDPRESS_DIR"

cat > "$PHP_FPM_CONFIG_FILE" << EOF
[www]
user = www-data
group = www-data
listen = 0.0.0.0:9000
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
clear_env = no
EOF

cd "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Waiting for MariaDB..."
until mariadb -h "$MDB_HOST" -u "$MDB_USER" -p"$DB_PASSWORD" "$MDB_DATABASE" -e "SELECT 1" >/dev/null 2>&1
do
	echo "[WORDPRESS] >> MariaDB is not ready yet..."
	sleep 2
done

if [ -f "$WP_CONFIG_FILE" ]; then
	echo "[WORDPRESS] >> WordPress already configured."
	echo "[WORDPRESS] >> Skipping installation."
else
	echo "[WORDPRESS] >> Downloading WordPress..."
	wp core download --allow-root

	echo "[WORDPRESS] >> Creating wp-config.php..."
	wp config create --dbname="$MDB_DATABASE" --dbuser="$MDB_USER" --dbpass="$DB_PASSWORD" --dbhost="$MDB_HOST" \
		--allow-root

	echo "[WORDPRESS] >> Installing WordPress..."
	wp core install --url="$WP_URL" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root

	echo "[WORDPRESS] >> Creating WordPress user..."
	wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$WP_USER_PASSWORD" --role=author --allow-root || true

	echo "[WORDPRESS] >> WordPress installation completed."
fi

echo "[WORDPRESS] >> Updating ownership..."
chown -R www-data:www-data "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Starting PHP-FPM..."
exec php-fpm8.2 -F