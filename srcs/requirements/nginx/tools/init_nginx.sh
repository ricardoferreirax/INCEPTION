#!/bin/bash

# Stop immediately if any command fails or if an undefined variable is used.
set -eu

NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_CONFIG_DIR="/etc/nginx/conf.d"
NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/default.conf"
NGINX_SSL_CERT="$NGINX_SSL_DIR/inception.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/inception.key"

mkdir -p "$NGINX_SSL_DIR"
mkdir -p "$NGINX_CONFIG_DIR"

# Create a self-signed certificate only if the certificate or its private key does not already exist.
if [ ! -f "$NGINX_SSL_CERT" ] || [ ! -f "$NGINX_SSL_KEY" ]; then
    echo "[NGINX] >> No SSL certificate found. Creating a new certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_KEY" -out "$NGINX_SSL_CERT" -subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"
else
    echo "[NGINX] >> Existing SSL certificate found. Reusing certificate."
fi

echo "[NGINX] >> Creating NGINX configuration file..."
# PHP requests are forwarded to PHP-FPM inside the WordPress container.
cat > "$NGINX_CONFIG_FILE" << EOF
server 
{
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ${DOMAIN_NAME};
    root /var/www/html;
    index index.php index.html;
    ssl_certificate ${NGINX_SSL_CERT};
    ssl_certificate_key ${NGINX_SSL_KEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    location / 
	{
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php$ 
	{
        include fastcgi_params;
        fastcgi_pass ${PHP_FPM_HOST}:${PHP_FPM_PORT};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTPS on;
    }
}
EOF
echo "[NGINX] >> NGINX configuration created successfully."
echo "[NGINX] >> Server name: $DOMAIN_NAME"
echo "[NGINX] >> PHP-FPM upstream: ${PHP_FPM_HOST}:${PHP_FPM_PORT}"

echo "[NGINX] >> Testing NGINX configuration..."
nginx -t

echo "[NGINX] >> Starting NGINX server in foreground..."
echo "[NGINX] >> Current Bash PID: $$"

# daemon off keeps NGINX in the foreground.
exec nginx -g "daemon off;"
