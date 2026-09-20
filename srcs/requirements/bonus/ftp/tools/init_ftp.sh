#!/bin/bash

# stop the script immediately if a command fails or if an undefined variable is used.
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

echo "[FTP] >> Creating directory where FTP user home and WordPress files are stored..."
mkdir -p "$FTP_ROOT"
mkdir -p "$VSFTPD_SECURE_DIR"

if ! id "ftpuser" >/dev/null 2>&1; then
    echo "[FTP] >> Creating FTP user..."
    useradd -d "$FTP_ROOT" -s /bin/bash ftpuser

	echo "[FTP] >> Setting FTP user password..."
    echo "ftpuser:${FTP_PASSWORD}" | chpasswd

	echo "[FTP] >> Adding FTP user to www-data group so it can work with the same files used by WP..."
    usermod -aG www-data ftpuser

    echo "[FTP] >> FTP user created successfully."
fi

echo "[FTP] >> Giving www-data ownership of the WordPress files..."
chown -R www-data:www-data "$FTP_ROOT"
chmod -R g+w "$FTP_ROOT"
echo "[FTP] >> Group write permission granted to the WP files so FTP user can modify them through FTP."

echo "[FTP] >> Creating vsftpd configuration file used by FTP server..."
cat > "$VSFTPD_CONFIG_FILE" << EOF
# listen for FTP connections using IPv4 on the standard FTP port
listen=YES
listen_ipv6=NO
listen_port=21

# disable anonymous access and only allow local system users
anonymous_enable=NO
local_enable=YES

# allow FTP user to upload, modify and delete files.
write_enable=YES

# enable passive FTP mode and define the ports used for data connections.
pasv_enable=YES
pasv_address=127.0.0.1
pasv_min_port=40000
pasv_max_port=40010

# restrict FTP user to its home directory.
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=${VSFTPD_SECURE_DIR}

# files created through FTP use standard read permissions and remain writable by their owner.
local_umask=022

# FTP connections are not encrypted with TLS.
ssl_enable=NO
EOF
echo "[FTP] >> vsftpd configuration created successfully."

echo "[FTP] >> Starting vsftpd server in foreground..."
exec vsftpd "$VSFTPD_CONFIG_FILE"
