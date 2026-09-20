#!/bin/bash

# stop the script immediately if a command fails or if an undefined variable is used.
set -eu

PORTAINER_DATA_DIR="/data"

echo "[PORTAINER] >> Creating directory where Portainer stores its persistent data..."
mkdir -p "$PORTAINER_DATA_DIR"

echo "[PORTAINER] >> Starting Portainer server in foreground..."
echo "[PORTAINER] >> Enables the internal HTTP server used by NGINX"
echo "[PORTAINER] >> Portainer is now accessible at https://${DOMAIN_NAME}/portainer/ in web browser."
exec /opt/portainer/portainer --data "$PORTAINER_DATA_DIR" --http-enabled --base-url "/portainer"
