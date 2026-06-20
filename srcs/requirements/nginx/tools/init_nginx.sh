#!/bin/bash

set -e

NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_CONFIG_DIR="/etc/nginx/conf.d"
NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/default.conf"
NGINX_SSL_CERT="$NGINX_SSL_DIR/inception.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/inception.key"

echo "[NGINX] >> Checking required environment variables..."
if [ -z "$DOMAIN_NAME" ] || [ -z "$PHP_FPM_HOST" ] || [ -z "$PHP_FPM_PORT" ]; then
	echo "[ERROR] >> DOMAIN_NAME, PHP_FPM_HOST or PHP_FPM_PORT is missing."
	exit 1
fi

if ! [[ "$PHP_FPM_PORT" =~ ^[0-9]+$ ]]; then
	echo "[ERROR] >> PHP_FPM_PORT must be a number."
	exit 1
fi

mkdir -p "$NGINX_SSL_DIR"
mkdir -p "$NGINX_CONFIG_DIR"

echo "[NGINX] >> Creating SSL certificate..."
if [ ! -f "$NGINX_SSL_CERT" ] || [ ! -f "$NGINX_SSL_KEY" ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_KEY" -out "$NGINX_SSL_CERT" \
		-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"
else
	echo "[NGINX] >> SSL certificate already exists. Reusing existing certificate."
fi

echo "[NGINX] >> Creating NGINX configuration file..."
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

echo "[NGINX] >> Starting NGINX in foreground..."
exec nginx -g "daemon off;"
