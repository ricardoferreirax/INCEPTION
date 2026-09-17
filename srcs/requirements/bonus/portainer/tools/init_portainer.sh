#!/bin/bash

# Stop immediately if any command fails or if an undefined variable is used.
set -eu

PORTAINER_DATA_DIR="/data"

# Create the directory where Portainer stores its persistent data.
mkdir -p "$PORTAINER_DATA_DIR"

echo "[PORTAINER] >> Starting Portainer in foreground..."
echo "[PORTAINER] >> Current Bash PID: $$"
exec /opt/portainer/portainer --data "$PORTAINER_DATA_DIR" --http-enabled --base-url "/portainer"
