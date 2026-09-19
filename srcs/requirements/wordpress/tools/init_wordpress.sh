#!/bin/bash

# stop the script if a command fails (-e) or if an undefined variable is used (-u).
set -eu

# define WP and PHP-FPM: the persistent dir where WP files are stored, the wp-config.php file
# used to identify if WP was already configured, the PHP-FPM runtime directory, and its config file.
WORDPRESS_DIR="/var/www/html"
WP_CONFIG_FILE="$WORDPRESS_DIR/wp-config.php"
PHP_FPM_RUN_DIR="/run/php"
PHP_FPM_CONFIG_FILE="/etc/php/8.2/fpm/pool.d/www.conf"

# check if the required Docker secrets exist and read the database and WP passwords.
if [ -f /run/secrets/db_password ] && [ -f /run/secrets/wp_admin_password ] && [ -f /run/secrets/wp_user_password ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password)
    WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
    WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
else
    echo "[ERROR] >> Required WordPress secrets not found."
    exit 1
fi

# build the complete HTTPS URL used by WP from the domain.
WP_FULL_URL="https://${DOMAIN_NAME}"

# create WP persistent dir and the PHP-FPM runtime dir.
mkdir -p "$WORDPRESS_DIR" "$PHP_FPM_RUN_DIR"

# WP and PHP-FPM run as www-data, so this user needs ownership of these directories.
chown -R www-data:www-data "$WORDPRESS_DIR" "$PHP_FPM_RUN_DIR"

echo "[WORDPRESS] >> Creating PHP-FPM pool configuration file..."
cat > "$PHP_FPM_CONFIG_FILE" << EOF
; define the PHP-FPM pool used to process WP PHP requests.
[www]

; run PHP-FPM worker processes as the www-data system user and using the www-data group.
user = www-data
group = www-data

; accept FastCGI connections on all container network interfaces. NGINX connects to this port through the Docker network.
listen = 0.0.0.0:${PHP_FPM_PORT}

; set www-data as the owner and as the group of the PHP-FPM listening endpoint.
listen.owner = www-data
listen.group = www-data

; use dynamic pm. PHP-FPM creates and removes worker processes according to the number of requests.
pm = dynamic

; define the maximum number of PHP-FPM worker processes that can exist simultaneously, limiting the nb of PHP requests.
pm.max_children = 5

; start PHP-FPM with two worker processes.
pm.start_servers = 2

; keep at least one idle worker available to handle new incoming requests.
pm.min_spare_servers = 1

; keep at most three idle workers.
pm.max_spare_servers = 3

; keep environment variables available to PHP-FPM workers instead of clearing them.
clear_env = no
EOF
echo "[WORDPRESS] >> PHP-FPM configuration created successfully."

# move into the persistent WP dir so WP-CLI executes its commands.
cd "$WORDPRESS_DIR"

# check if WP has already been configured, preventing WP and its users from being recreated.
if [ ! -f "$WP_CONFIG_FILE" ]; then

    echo "[WORDPRESS] >> No wp-config.php found! Initializing WordPress..."

    echo "[WORDPRESS] >> Downloading WordPress core files..."
    wp core download --allow-root

    echo "[WORDPRESS] >> Creating wp-config.php file with MariaDB connection information..."
    wp config create --dbname="wordpress" --dbuser="$MDB_USER" --dbpass="$DB_PASSWORD" --dbhost="mariadb:${MDB_PORT}" --allow-root

    echo "[WORDPRESS] >> Installing and configuring WordPress website..."
    wp core install --url="$WP_FULL_URL" --title="Inception" --admin_user="$WP_ADMIN" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root

    echo "[WORDPRESS] >> Creating second WordPress user..."
    wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$WP_USER_PASSWORD" --role="author" --allow-root

    echo "[WORDPRESS] >> Configuring WordPress to connect to Redis..."
    wp config set WP_REDIS_HOST "redis" --allow-root
    wp config set WP_REDIS_PORT 6379 --raw --allow-root

    echo "[WORDPRESS] >> Installing Redis Object Cache plugin..."
    wp plugin install redis-cache --activate --allow-root

    echo "[WORDPRESS] >> Enabling Redis as the WordPress object cache..."
    wp redis enable --allow-root

    echo "[WORDPRESS] >> WordPress initialization completed."
else
    echo "[WORDPRESS] >> WordPress already initialized. Skipping installation."
fi

echo "[WORDPRESS] >> Updating WordPress home and siteurl options to use correct HTTPS domain..."
wp option update home "$WP_FULL_URL" --allow-root
wp option update siteurl "$WP_FULL_URL" --allow-root

# give www-data user ownership of persistent WP files so PHP-FPM can read and modify them.
echo "[WORDPRESS] >> Updating WordPress file ownership..."
chown -R www-data:www-data "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Starting PHP-FPM server in foreground..."
echo "[WORDPRESS] >> Current Bash PID: $$"
# exec replaces the Bash process with PHP-FPM, making PHP-FPM PID 1 inside the container.
# docker can then send signals directly to PHP-FPM, allowing it to shut down correctly while keeping
# the container running in foreground.
exec php-fpm8.2 -F
