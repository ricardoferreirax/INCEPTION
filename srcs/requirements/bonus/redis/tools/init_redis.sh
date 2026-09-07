#!/bin/bash

# stop immediately if any command fails or if an undefined variable is used.
set -eu

REDIS_CONFIG_FILE="/etc/redis/redis.conf"

echo "[REDIS] >> Creating Redis configuration file..."

# redis listens on all interfaces inside the Docker network, port 6379 is only exposed internally to the other containers.
# redis runs in foreground so it can be managed directly by Docker. 
# Persistence is disabled because Redis is used only as a cache for the WordPress service.
cat > "$REDIS_CONFIG_FILE" << EOF
bind 0.0.0.0
port 6379
protected-mode no
daemonize no
save ""
appendonly no
EOF

echo "[REDIS] >> Starting Redis in foreground..."

# exec replaces the Bash script with redis-server, making Redis PID 1 inside the container.
exec redis-server "$REDIS_CONFIG_FILE"
