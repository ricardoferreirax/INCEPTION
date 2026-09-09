#!/bin/bash

# Stop immediately if any command fails or if an undefined variable is used.
set -eu

ADMINER_DIR="/var/www/html"
ADMINER_FILE="$ADMINER_DIR/index.php"

mkdir -p "$ADMINER_DIR"

if [ ! -f "$ADMINER_FILE" ]; then
    echo "[ADMINER] >> Adminer file not found. Downloading Adminer..."
    curl -fsSL "https://github.com/vrana/adminer/releases/download/v6.0.2/adminer-6.0.2-mysql.php" -o "$ADMINER_FILE"
    echo "[ADMINER] >> Adminer downloaded successfully."
else
    echo "[ADMINER] >> Existing Adminer file found. Skipping download."
fi

chown -R www-data:www-data "$ADMINER_DIR"

echo "[ADMINER] >> Starting Adminer server in foreground..."
echo "[ADMINER] >> Current Bash PID: $$"

exec php -S "0.0.0.0:8080" -t "$ADMINER_DIR"
