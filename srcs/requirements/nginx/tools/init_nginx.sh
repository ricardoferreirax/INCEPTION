#!/bin/bash

# stop immediately if any command fails and if an undefined variable is used.
set -eu

NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_CONFIG_DIR="/etc/nginx/conf.d"
NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/default.conf"
NGINX_SSL_CERT="$NGINX_SSL_DIR/inception.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/inception.key"

mkdir -p "$NGINX_SSL_DIR"
mkdir -p "$NGINX_CONFIG_DIR"

echo "[NGINX] >> Checking SSL certificate..."

# create a self-signed certificate only if the certificate or its private key doesn't already exist.
# NGINX will use this certificate to provide HTTPS connections on port 443.
if [ ! -f "$NGINX_SSL_CERT" ] || [ ! -f "$NGINX_SSL_KEY" ]; then
	echo "[NGINX] >> Creating SSL certificate..."

	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_KEY" -out "$NGINX_SSL_CERT" -subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"

else
	echo "[NGINX] >> SSL certificate already exists. Reusing existing certificate."

fi

echo "[NGINX] >> Creating NGINX configuration file..."

# create the NGINX server config, NGINX listens only on HTTPS port 443, only TLS 1.2 and TLS 1.3 are enabled.
# static WordPress files are served directly by NGINX, PHP files are forwarded to PHP-FPM running inside the WordPress container.
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

echo "[NGINX] >> Testing NGINX configuration..."

# validate the generated config before starting NGINX.
nginx -t

echo "[NGINX] >> Starting NGINX in foreground..."

# daemon off keeps NGINX running in the foreground, exec replaces this Bash script with the NGINX process, making NGINX PID 1 inside the container.
exec nginx -g "daemon off;"
