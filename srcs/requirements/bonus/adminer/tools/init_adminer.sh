#!/bin/bash

# stop the script immediately if a command fails or if an undefined variable is used.
set -eu

# define path of the PHP file used to start the application.
ADMINER_DIR="/var/www/html"
ADMINER_FILE="$ADMINER_DIR/index.php"

echo "[ADMINER] >> Creating directory where Adminer PHP file will be stored..."
mkdir -p "$ADMINER_DIR"

echo "[ADMINER] >> Checking if Adminer is already downloaded..."
if [ ! -f "$ADMINER_FILE" ]; then
    echo "[ADMINER] >> Downloading Adminer..."
    curl -fsSL "https://github.com/vrana/adminer/releases/download/v6.0.2/adminer-6.0.2-mysql.php" -o "$ADMINER_FILE"

    echo "[ADMINER] >> Adminer downloaded successfully."
fi

echo "[ADMINER] >> Giving the web server user www-data ownership of the Adminer files..."
chown -R www-data:www-data "$ADMINER_DIR"

echo "[ADMINER] >> Start Adminer PHP's built-in web server in foreground..."
echo "[ADMINER] >> Allows connections from other containers and serves the Adminer PHP file..."
echo "[ADMINER] >> Adminer is now accessible at https://${DOMAIN_NAME}/adminer/ in web browser."
exec php -S "0.0.0.0:8080" -t "$ADMINER_DIR"
