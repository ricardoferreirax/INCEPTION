#!/bin/bash

# stop if any command fails or if an undefined variable is used.
set -eu

WORDPRESS_DIR="/var/www/html"
WP_CONFIG_FILE="$WORDPRESS_DIR/wp-config.php"
PHP_FPM_RUN_DIR="/run/php"
PHP_FPM_CONFIG_DIR="/etc/php/8.2/fpm/pool.d"
PHP_FPM_CONFIG_FILE="$PHP_FPM_CONFIG_DIR/www.conf"

if [ -f /run/secrets/db_password ] && [ -f /run/secrets/wp_admin_password ] && [ -f /run/secrets/wp_user_password ]; then
    DB_PASSWORD=$(cat /run/secrets/db_password)
    WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
    WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
else
    echo "[ERROR] >> Required WordPress secrets not found."
    exit 1
fi

# build complete HTTPS URL used by WordPress.
WP_FULL_URL="https://${DOMAIN_NAME}"

# create wp and php-fpm runtime dir.
mkdir -p "$WORDPRESS_DIR"
mkdir -p "$PHP_FPM_RUN_DIR"
mkdir -p "$PHP_FPM_CONFIG_DIR"

# allow web server user to manage WordPress and php-fpm runtime files.
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
echo "[WORDPRESS] >> PHP-FPM configuration created successfully."

# move into the wp dir so wp-cli uses the correct installation.
cd "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Waiting for MariaDB connection..."
MARIADB_READY=0
for i in {1..10}; do
    # verify that mariadb is ready and the wp credentials work.
    if mariadb -h mariadb -P "$MDB_PORT" -u "rmedeiro" -p"$DB_PASSWORD" "wordpress" -e "SELECT 1" >/dev/null 2>&1
    then
        MARIADB_READY=1
        echo "[WORDPRESS] >> MariaDB connection established."
        break
    fi
    echo "[WORDPRESS] >> Waiting for MariaDB to be ready..."
    sleep 2
done

if [ "$MARIADB_READY" -ne 1 ]; then
    echo "[ERROR] >> WordPress could not connect to MariaDB."
    exit 1
fi

# install wp only if wp-config.php does not exist.
if [ ! -f "$WP_CONFIG_FILE" ]; then
    echo "[WORDPRESS] >> No wp-config.php found. WordPress installation is required."

    echo "[WORDPRESS] >> Downloading WordPress core files..."
    wp core download --allow-root

    echo "[WORDPRESS] >> Creating wp-config.php..."
    wp config create --dbname="wordpress" --dbuser="rmedeiro" --dbpass="$DB_PASSWORD" --dbhost="mariadb:${MDB_PORT}" --allow-root

    echo "[WORDPRESS] >> Installing WordPress site..."
    wp core install --url="$WP_FULL_URL" --title="Inception" --admin_user="rmedeiro" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="rmedeiro@student.42lisboa.com" --skip-email --allow-root

    echo "[WORDPRESS] >> Creating second WordPress user..."
    wp user create "wpuser" "wpuser@example.com" --user_pass="$WP_USER_PASSWORD" --role="author" --allow-root

    echo "[WORDPRESS] >> WordPress initialization completed."
else
    echo "[WORDPRESS] >> Existing wp-config.php! Skip reinstalling WordPress and recreating users!"
fi

# update wp home url to use the configured domain -> this is the url visitors use to access the website.
wp option update home "$WP_FULL_URL" --allow-root

# update wp site url to use the configured domain -> this tells WordPress where its core files are accessible.
wp option update siteurl "$WP_FULL_URL" --allow-root

# check if the redis container can be found on the Docker network.
if getent hosts redis >/dev/null 2>&1; then
    echo "[WORDPRESS] >> Redis service detected. Configuring Redis cache..."
    # set redis hostname used by wp. "redis" is the name used through the Docker network.
    wp config set WP_REDIS_HOST "redis" --allow-root
    # set port used by wp to communicate with redis.
    wp config set WP_REDIS_PORT 6379 --raw --allow-root

    # check if redis plugin is already installed.
    if ! wp plugin is-installed redis-cache --allow-root; then
        echo "[WORDPRESS] >> Installing Redis Object Cache plugin..."
        # download, install and activate the redis plugin, which allows wp to use redis for object caching.
        wp plugin install redis-cache --activate --allow-root
    else
        echo "[WORDPRESS] >> Redis Object Cache plugin already installed."
        # activate plugin if it already exists but is currently disabled.
        wp plugin activate redis-cache --allow-root >/dev/null 2>&1 || true
    fi

    echo "[WORDPRESS] >> Enabling Redis Object Cache..."
    # enable redis inside wp -> this creates wp object-cache.php drop-in used by the plugin.
    wp redis enable --allow-root
else
    echo "[WORDPRESS] >> Redis service not available. Skipping Redis cache."
fi

echo "[WORDPRESS] >> Updating WordPress file ownership..."
chown -R www-data:www-data "$WORDPRESS_DIR"

echo "[WORDPRESS] >> Starting PHP-FPM server in foreground..."
echo "[WORDPRESS] >> Current Bash PID: $$"
exec php-fpm8.2 -F
