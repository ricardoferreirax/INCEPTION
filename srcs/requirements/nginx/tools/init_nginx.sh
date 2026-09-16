#!/bin/bash

# stop immediately if any command fails or if an undefined variable is used.
set -eu

NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_CONFIG_DIR="/etc/nginx/conf.d"
NGINX_CONFIG_FILE="$NGINX_CONFIG_DIR/default.conf"
NGINX_SSL_CERT="$NGINX_SSL_DIR/inception.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/inception.key"

# create the directory where NGINX stores its SSL files.
mkdir -p "$NGINX_SSL_DIR"
mkdir -p "$NGINX_CONFIG_DIR"

if [ ! -f "$NGINX_SSL_CERT" ] || [ ! -f "$NGINX_SSL_KEY" ]; then
    echo "[NGINX] >> No SSL certificate found. Creating a new certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_KEY" -out "$NGINX_SSL_CERT" \
        -subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"
    echo "[NGINX] >> SSL certificate created successfully."
else
    echo "[NGINX] >> Existing SSL certificate found. Reusing certificate."
fi

echo "[NGINX] >> Creating NGINX configuration file..."
# check if the adminer service becomes available.
ADMINER_AVAILABLE=0
for i in {1..5}; do
    if getent hosts adminer >/dev/null 2>&1; then
        ADMINER_AVAILABLE=1
        break
    fi
    echo "[NGINX] >> Waiting for Adminer..."
    sleep 1
done

if [ "$ADMINER_AVAILABLE" -eq 1 ]; then
    echo "[NGINX] >> Adminer detected. Creating bonus configuration."
    cat > "$NGINX_CONFIG_FILE" << EOF
server 
{
    listen ${NGINX_PORT} ssl;
    listen [::]:${NGINX_PORT} ssl;
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
        fastcgi_pass wordpress:${PHP_FPM_PORT};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTPS on;
    }
    location /adminer/ 
	{
        proxy_pass http://adminer:8080/;
    }
    location /static/ 
	{
        proxy_pass https://static/;
        proxy_ssl_verify off;
    }
}
EOF
    echo "[NGINX] >> Bonus configuration created successfully."
else
    echo "[NGINX] >> Adminer not detected. Creating mandatory configuration."
    cat > "$NGINX_CONFIG_FILE" << EOF
server 
{
    listen ${NGINX_PORT} ssl;
    listen [::]:${NGINX_PORT} ssl;
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
        fastcgi_pass wordpress:${PHP_FPM_PORT};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTPS on;
    }
}
EOF
    echo "[NGINX] >> Mandatory configuration created successfully."
fi

echo "[NGINX] >> Testing NGINX configuration..."
nginx -t

echo "[NGINX] >> Starting NGINX server in foreground..."
echo "[NGINX] >> Current Bash PID: $$"
exec nginx -g "daemon off;"
