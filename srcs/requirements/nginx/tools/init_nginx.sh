#!/bin/bash

# stop the script immediately if a command fails or if an undefined variable is used.
set -eu

# define paths used to store SSL, private key, and the server config for NGINX.
NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_CONFIG_FILE="/etc/nginx/conf.d/default.conf"
NGINX_SSL_CERT="$NGINX_SSL_DIR/inception.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/inception.key"

# create the dir where SSL and private key will be stored.
mkdir -p "$NGINX_SSL_DIR"

# -x509      creates a self-signed certificate.
# -nodes     creates the private key without password protection.
# -days 365  makes the certificate valid for 365 days.
# -newkey    creates a new private key together with the certificate.
# rsa:2048   uses a 2048-bit RSA private key.
# -keyout    defines where the private key is stored.
# -out       defines where the certificate is stored.
# -subj      provides the certificate information without interactive input.
echo "[NGINX] >> Creating a self-signed SSL certificate so NGINX can accept HTTPS connections..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_KEY" -out "$NGINX_SSL_CERT" \
			-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"

echo "[NGINX] >> Creating NGINX server configuration file..."
cat > "$NGINX_CONFIG_FILE" << EOF
server
{
    # accept HTTPS connections on port 443 using IPv4 and IPv6
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name ${DOMAIN_NAME};

    # define dir containing the WP files and the default files that NGINX should look for
    root /var/www/html;
    index index.php index.html;

    # configure the SSL certificate and private key used for HTTPS
    ssl_certificate ${NGINX_SSL_CERT};
    ssl_certificate_key ${NGINX_SSL_KEY};

    ssl_protocols TLSv1.2 TLSv1.3;

    # NGINX first looks for an existing file or dir. If don't exists, the request is forwarded to WP through index.php.
    location /
    {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # handle php files using PHP-FPM from the WP container. NGINX doesn't execute PHP itself, 
	# so PHP requests are sent to the WordPress container using the FastCGI protocol.
    location ~ \.php$
    {
        include fastcgi_params;

        # send php requests to PHP-FPM through the docker network
        fastcgi_pass wordpress:${PHP_FPM_PORT};

        fastcgi_index index.php;

        # tell PHP-FPM the complete path of the PHP file to execute
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;

        # tell WP that the original request uses HTTPS.
        fastcgi_param HTTPS on;
    }

    # forward requests under /adminer/ to the adminer container.
    location /adminer/
    {
        proxy_pass http://adminer:8080/;
    }

    # forward requests under /static/ to the static website container.
    location /static/
    {
        proxy_pass https://static/;

        # static uses a self-signed certificate, so certificate verification is disabled for this internal connection.
        proxy_ssl_verify off;
    }

    # forward requests under /portainer/ to the portainer container.
    location /portainer/
    {
        proxy_pass http://portainer:9000/;

        proxy_http_version 1.1;

        # preserve information about the original client request when forwarding it to Portainer.
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # forward the headers required for WebSocket connection upgrades.
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
echo "[NGINX] >> NGINX configuration created successfully."

echo "[NGINX] >> Testing the generated NGINX configuration before starting the server..."
nginx -t

echo "[NGINX] >> Starting NGINX server in foreground..."
echo "[NGINX] >> Preventing NGINX from moving to the background so Docker can keep the container running..."
exec nginx -g "daemon off;"
