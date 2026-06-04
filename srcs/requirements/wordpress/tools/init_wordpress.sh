#!/bin/bash

# Stop the script if any command fails. Prevents the container from continuing with a broken WordPress setup.
set -e

# Define the path where WordPress files will be stored. This path is connected to the WordPress volume.
WP_PATH="/var/www/html"

# Reads the passwords from the Docker secret.
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# Create the PHP-FPM runtime directory. PHP-FPM needs this to store runtime files.
# Also, create the WordPress directory if it does not already exist.
mkdir -p /run/php
mkdir -p "$WP_PATH"

# Give ownership of the WordPress directory and PHP runtime directory to www-data.
# PHP-FPM runs as www-data, so it needs permission to read and write these files.
chown -R www-data:www-data "$WP_PATH" /run/php

# Move into the WordPress directory. WP-CLI commands will be executed from here.
cd "$WP_PATH"

echo "Waiting for MariaDB..."

# Try to connect to MariaDB using the database host, user, password, and database name.
# The command runs a SQL query: SELECT 1; If the connection fails, the loop continues.
# >/dev/null hides normal output. 2>&1 hides error output too.
until mariadb -h"$MDB_HOST" -u"$MDB_USER" -p"$DB_PASSWORD" "$MDB_DATABASE" -e "SELECT 1;" >/dev/null 2>&1; do
	
	# If the connection fails, print a message and wait before trying again. This loop will keep running until MariaDB is ready to accept connections.
	echo "MariaDB is not ready yet..."
	
	# Wait for 2 seconds before trying again. This prevents the loop from overwhelming the database with connection attempts.
	sleep 2

# When MariaDB accepts the connection, the loop will exit and the script will continue to the next steps.
done

echo "MariaDB is ready."

# Check if wp-config.php does not exist. If it does not exist, WordPress has not been configured yet.
# This prevents reinstalling WordPress every time the container restarts.
if [ ! -f "$WP_PATH/wp-config.php" ]; then
	
	# Download the WordPress core files into WP_PATH.
	# --allow-root is needed because the script runs as root inside the container. | --path tells WP-CLI where WordPress should be installed.
	echo "Downloading WordPress..."
	wp core download --allow-root --path="$WP_PATH"

	# --dbname is the MariaDB database name. | --dbuser is the MariaDB user. | --dbpass is the MariaDB user password.
	# --dbhost is the MariaDB service name and port, for example mariadb:3306.
	echo "Creating wp-config.php..."
	wp config create --allow-root --path="$WP_PATH" --dbname="$MDB_DATABASE" \
		--dbuser="$MDB_USER" --dbpass="$DB_PASSWORD" --dbhost="$MDB_HOST:$MDB_PORT"

	# --url defines the website URL. | --title defines the website title. | --admin_user creates the administrator account.
	# --admin_password sets the administrator password. | --admin_email sets the administrator email.
	echo "Installing WordPress..."
	wp core install --allow-root --path="$WP_PATH" --url="$WP_URL" --title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL"

	# "$WP_USER" is the username. | "$WP_USER_EMAIL" is the user email. | --user_pass sets the user password from Docker secrets.
	# --role=author gives this user the author role.
	echo "Creating normal WordPress user..."
	wp user create "$WP_USER" "$WP_USER_EMAIL" --allow-root --path="$WP_PATH" --user_pass="$WP_USER_PASSWORD" \
		--role=author

	# After installing WordPress, make www-data the owner of all WordPress files. This allows PHP-FPM to manage WordPress files correctly.
	chown -R www-data:www-data "$WP_PATH"

	echo "WordPress installation completed."

else # If wp-config.php already exists, the script skips the installation.

	echo "WordPress already configured."
fi

echo "Starting PHP-FPM..."

# Start PHP-FPM in the foreground. exec replaces the shell script process with the PHP-FPM process.
# -F keeps PHP-FPM in the foreground, which keeps the container running.
exec php-fpm8.2 -F