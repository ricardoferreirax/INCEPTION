#!/bin/bash

set -e

NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_CONFIG_DIR="/etc/nginx/conf.d"
NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/default.conf"
NGINX_SSL_CERT="$NGINX_SSL_DIR/inception.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/inception.key"

echo "[NGINX] >> Checking required environment variables..."
if [ -z "$DOMAIN_NAME" ] || [ -z "$PHP_FPM_HOST" ] || [ -z "$PHP_FPM_PORT" ] || [ -z "$NGINX_PORT" ]; then
	echo "[ERROR] >> DOMAIN_NAME, PHP_FPM_HOST, PHP_FPM_PORT or NGINX_PORT is missing."
	exit 1
fi

if ! [[ "$PHP_FPM_PORT" =~ ^[0-9]+$ ]] || ! [[ "$NGINX_PORT" =~ ^[0-9]+$ ]]; then
	echo "[ERROR] >> PHP_FPM_PORT and NGINX_PORT must be numbers."
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

# Creates the NGINX server configuration file with the necessary settings to serve the WordPress site.
# The configuration sets up a server block that listens on port 443 for HTTPS connections, serves content from the /var/www/html directory, 
# and forwards PHP requests to the PHP-FPM service defined by PHP_FPM_HOST.
echo "[NGINX] >> Creating NGINX configuration file..."
cat > "$NGINX_CONFIG_FILE" << EOF
server {

	listen ${NGINX_PORT} ssl;
	listen [::]:${NGINX_PORT} ssl;

	server_name ${DOMAIN_NAME};

	root /var/www/html;
	index index.php index.html;

	ssl_certificate ${NGINX_SSL_CERT};
	ssl_certificate_key ${NGINX_SSL_KEY};

	ssl_protocols TLSv1.2 TLSv1.3;

	location / {
		try_files \$uri \$uri/ /index.php?\$args;
	}

	location ~ \.php$ {
		include fastcgi_params;
		fastcgi_pass ${PHP_FPM_HOST}:${PHP_FPM_PORT};
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		fastcgi_param HTTPS on;
		fastcgi_param SERVER_PORT ${NGINX_PORT};
		fastcgi_param HTTP_HOST \$host:${NGINX_PORT};
	}

}
EOF

echo "[NGINX] >> Starting NGINX in foreground..."
exec nginx -g "daemon off;"
