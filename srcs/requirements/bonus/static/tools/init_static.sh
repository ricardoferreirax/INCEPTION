#!/bin/bash

# stop the script immediately if a command fails or if an undefined variable is used.
set -eu

STATIC_DIR="/var/www/html"
NGINX_CONFIG_FILE="/etc/nginx/nginx.conf"
NGINX_SSL_DIR="/etc/nginx/ssl"
NGINX_SSL_CERT="$NGINX_SSL_DIR/static.crt"
NGINX_SSL_KEY="$NGINX_SSL_DIR/static.key"

# create dirs required by static website and SSL config
mkdir -p "$STATIC_DIR" "$NGINX_SSL_DIR"

echo "[STATIC] >> Creating a self-signed SSL certificate for the static website..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_KEY" -out "$NGINX_SSL_CERT" \
    		-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=static"

echo "[STATIC] >> Creating the NGINX configuration file to serve the static website..."
cat > "$NGINX_CONFIG_FILE" << EOF
# define the NGINX event processing context.
events
{
}

# define the HTTP server configuration.
http
{
    # allows NGINX to return the correct content type for files such as html, css and js.
    include /etc/nginx/mime.types;

    server
    {
        # accept HTTPS connections on port 443.
        listen 443 ssl;

        # configure SSL certificate and private key used by static website.
        ssl_certificate ${NGINX_SSL_CERT};
        ssl_certificate_key ${NGINX_SSL_KEY};

        ssl_protocols TLSv1.2 TLSv1.3;

        # define the dir containing the static website files.
        root ${STATIC_DIR};

        # use index.html as the default page when a dir is requested.
        index index.html;

        # NGINX first tries to find the requested file. If the request points to a dir, it tries that dir.
        # If don't exists, NGINX returns HTTP 404.
        location /
        {
            try_files \$uri \$uri/ =404;
        }
    }
}
EOF
echo "[STATIC] >> NGINX configuration created successfully."

echo "[STATIC] >> Testing the generated NGINX configuration before starting the server..."
nginx -t

echo "[STATIC] >> Starting NGINX server in foreground..."
echo "[NGINX] >> Preventing NGINX from moving to the background so Docker can keep the container running..."
exec nginx -g "daemon off;"
