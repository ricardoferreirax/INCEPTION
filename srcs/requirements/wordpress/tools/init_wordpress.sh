#!/bin/bash

# stop immediately if any command fails and if an undefined variable is used.
set -eu

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

# build the complete HTTPS URL used by WordPress.
WP_FULL_URL="https://${DOMAIN_NAME}"

mkdir -p "$WORDPRESS_DIR"
mkdir -p "$PHP_FPM_RUN_DIR"
mkdir -p "$PHP_FPM_CONFIG_DIR"

chown -R www-data:www-data "$WORDPRESS_DIR" "$PHP_FPM_RUN_DIR"

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

# move into the WordPress dir so WP-CLI commands operate on the correct installation.
cd "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Waiting for MariaDB..."

# start assuming MariaDB is unavailable.
MARIADB_READY=0

for i in {1..10}; do

	# attempt a SQL query using the WordPress database account.
	if mariadb -h "$MDB_HOST" -P "$MDB_PORT" -u "$MDB_USER" -p"$DB_PASSWORD" "$MDB_DATABASE" -e "SELECT 1" >/dev/null 2>&1
	then
		# if this succeeds, MariaDB is running, the database exists, the user exists and pass is correct.
		MARIADB_READY=1
		break
	fi
	echo "[WORDPRESS] >> MariaDB is not ready yet..."
	sleep 2

done

# if MariaDB is still unavailable after all attempts, we stop container instead of waiting forever.
if [ "$MARIADB_READY" -ne 1 ]; then
	echo "[ERROR] >> MariaDB connection failed."
	exit 1
fi

# install WordPress only when wp-config.php doesn't exist, this prevents from being reinstalled on every restart.
if [ ! -f "$WP_CONFIG_FILE" ]; then

	echo "[WORDPRESS] >> Downloading WordPress core files..."
	wp core download --allow-root

	echo "[WORDPRESS] >> Creating wp-config.php..."
	# create wp-config.php with the MariaDB connection information. The host uses name "mariadb" instead of localhost cause MariaDB runs in another container.
	wp config create --dbname="$MDB_DATABASE" --dbuser="$MDB_USER" --dbpass="$DB_PASSWORD" --dbhost="${MDB_HOST}:${MDB_PORT}" --allow-root

	echo "[WORDPRESS] >> Installing WordPress site..."
	# perform the initial WordPress installation, this creates the site config and the admin account.
	wp core install --url="$WP_FULL_URL" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root

	echo "[WORDPRESS] >> Creating the second WordPress user..."
	wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$WP_USER_PASSWORD" --role="$WP_USER_ROLE" --allow-root

	echo "[WORDPRESS] >> WordPress installation completed."

else
	echo "[WORDPRESS] >> Existing WordPress installation detected."

fi

echo "[WORDPRESS] >> Updating WordPress file ownership..."
chown -R www-data:www-data "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Starting PHP-FPM in foreground..."

# -F keeps PHP-FPM in the foreground, exec replaces this Bash script with PHP-FPM, making PHP-FPM PID 1 inside the container.
exec php-fpm8.2 -F
