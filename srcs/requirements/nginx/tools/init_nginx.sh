#!/bin/bash

set -eu

NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_CONFIG_DIR="/etc/nginx/conf.d"
NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/default.conf"
NGINX_SSL_CERT="$NGINX_SSL_DIR/inception.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/inception.key"

mkdir -p "$NGINX_SSL_DIR"
mkdir -p "$NGINX_CONFIG_DIR"

if [ ! -f "$NGINX_SSL_CERT" ] || [ ! -f "$NGINX_SSL_KEY" ]; then
    echo "[NGINX] >> No SSL certificate found. Creating a new certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_KEY" -out "$NGINX_SSL_CERT" -subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"
else
    echo "[NGINX] >> Existing SSL certificate found. Reusing certificate."
fi

echo "[NGINX] >> Creating NGINX configuration file..."
if [ "${BONUS_MODE:-0}" = "1" ]; then
    echo "[NGINX] >> Using bonus configuration."
    cp /tmp/server-bonus.conf "$NGINX_CONFIG_FILE"
else
    echo "[NGINX] >> Using mandatory configuration."
    cp /tmp/server.conf "$NGINX_CONFIG_FILE"
fi

echo "[NGINX] >> Testing NGINX configuration..."
nginx -t

echo "[NGINX] >> Starting NGINX server in foreground..."
exec nginx -g "daemon off;"
