#!/bin/bash

# stop the script immediately if a command fails or if an undefined variable is used.
set -eu

# path of the NGINX config file and dir where the static website files are stored.
NGINX_CONFIG_FILE="/etc/nginx/nginx.conf"
STATIC_DIR="/var/www/html"

# create dir where the static website files are stored.
mkdir -p "$STATIC_DIR"

echo "[STATIC] >> Creating the NGINX configuration file to serve the static website..."
cat > "$NGINX_CONFIG_FILE" << EOF
# NGINX event processing context. No custom event config is required for static website.
events
{
}

# define HTTP server config.
http
{
    # allows NGINX to identify HTML, CSS and JS files.
    include /etc/nginx/mime.types;

    server
    {
        # listen on port 8081 inside the network. NGINX forwards /static/ requests to this port.
        listen 8081;

        # dir containing the static website files.
        root ${STATIC_DIR};

        # define index.html as the default page.
        index index.html;

        # NGINX first tries to find the requested file. If refers to a dir, it tries that dir.
        # if neither exists, NGINX returns HTTP 404.
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
exec nginx -g "daemon off;"
