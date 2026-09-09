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

# create FTP user only if it does not already exist, the home dir points directly to the WordPress files.
if ! id "$FTP_USER" >/dev/null 2>&1; then
    echo "[FTP] >> FTP user not found. Creating user: $FTP_USER"
    useradd -d "$FTP_ROOT" -s /bin/bash "$FTP_USER"

    # set FTP user's password using the Docker secret.
    echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd

    # add FTP user to www-data group so it can access files shared with the WordPress container.
    usermod -aG www-data "$FTP_USER"

    echo "[FTP] >> FTP user created successfully."
else
    echo "[FTP] >> Existing FTP user found. Skipping user creation."
fi

chown -R www-data:www-data "$FTP_ROOT"

# give www-data group write permission so the FTP user can upload, modify and delete files.
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
echo "[FTP] >> Passive port range: 40000-40010"

echo "[FTP] >> Starting vsftpd server in foreground..."
echo "[FTP] >> Current Bash PID: $$"

exec vsftpd "$VSFTPD_CONFIG_FILE"
