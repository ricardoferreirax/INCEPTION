#!/bin/bash

# Stop immediately if any command fails or if an undefined variable is used.
set -eu

FTP_ROOT="/var/www/html"
VSFTPD_CONFIG_FILE="/etc/vsftpd.conf"
VSFTPD_SECURE_DIR="/var/run/vsftpd/empty"

if [ -f /run/secrets/ftp_password ]; then
    FTP_PASSWORD=$(cat /run/secrets/ftp_password)
else
    echo "[ERROR] >> Required FTP secret not found."
    exit 1
fi

mkdir -p "$FTP_ROOT"
mkdir -p "$VSFTPD_SECURE_DIR"

# Create FTP user only if it does not already exist.
# The home directory points directly to the WordPress files.
if ! id "ftpuser" >/dev/null 2>&1; then
    echo "[FTP] >> FTP user not found. Creating user..."
    useradd -d "$FTP_ROOT" -s /bin/bash "ftpuser"
    # Set FTP user's password using the Docker secret.
    echo "ftpuser:${FTP_PASSWORD}" | chpasswd
    # Add FTP user to www-data group so it can access files shared with WordPress.
    usermod -aG www-data "ftpuser"
    echo "[FTP] >> FTP user created successfully."
else
    echo "[FTP] >> Existing FTP user found. Skipping user creation."
fi

chown -R www-data:www-data "$FTP_ROOT"

# Give www-data group write permission so the FTP user can upload,
# modify and delete files.
chmod -R g+w "$FTP_ROOT"

echo "[FTP] >> Creating vsftpd configuration file..."
cat > "$VSFTPD_CONFIG_FILE" << EOF
listen=YES
listen_ipv6=NO
listen_port=21
anonymous_enable=NO
local_enable=YES
write_enable=YES
pasv_enable=YES
pasv_address=127.0.0.1
pasv_min_port=40000
pasv_max_port=40010
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=${VSFTPD_SECURE_DIR}
local_umask=022
ssl_enable=NO
EOF
echo "[FTP] >> vsftpd configuration created successfully."

echo "[FTP] >> Starting vsftpd server in foreground..."
echo "[FTP] >> Current Bash PID: $$"
exec vsftpd "$VSFTPD_CONFIG_FILE"
