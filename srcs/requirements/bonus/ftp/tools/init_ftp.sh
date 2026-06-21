#!/bin/bash

set -e

FTP_ROOT_DIR="/var/www/html"
FTP_CONFIG_FILE="/etc/vsftpd.conf"
FTP_USERLIST_FILE="/etc/vsftpd.userlist"
FTP_PASSWORD_FILE="/run/secrets/ftp_password"

echo "[FTP] >> Verifying required Docker secrets..."
if [ -f "$FTP_PASSWORD_FILE" ]; then
	FTP_PASSWORD=$(cat "$FTP_PASSWORD_FILE")
else
	echo "[ERROR] >> ftp_password secret not found."
	exit 1
fi

echo "[FTP] >> Checking required environment variables..."
if [ -z "$FTP_USER" ] || [ -z "$FTP_PASV_MIN_PORT" ] || [ -z "$FTP_PASV_MAX_PORT" ]; then
	echo "[ERROR] >> FTP_USER, FTP_PASV_MIN_PORT or FTP_PASV_MAX_PORT is missing."
	exit 1
fi

mkdir -p "$FTP_ROOT_DIR"
mkdir -p /var/run/vsftpd/empty

echo "[FTP] >> Creating FTP user..."
if ! id "$FTP_USER" >/dev/null 2>&1; then
	useradd -m -d "$FTP_ROOT_DIR" -s /bin/bash "$FTP_USER"
fi

echo "$FTP_USER:$FTP_PASSWORD" | chpasswd

echo "[FTP] >> Creating vsftpd user list..."
echo "$FTP_USER" > "$FTP_USERLIST_FILE"

echo "[FTP] >> Updating FTP root ownership..."
chown -R "$FTP_USER:$FTP_USER" "$FTP_ROOT_DIR"
chmod -R 755 "$FTP_ROOT_DIR"

echo "[FTP] >> Creating vsftpd configuration file..."
cat > "$FTP_CONFIG_FILE" << EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
pasv_address=${DOMAIN_NAME}
allow_writeable_chroot=YES
local_root=${FTP_ROOT_DIR}
pasv_enable=YES
pasv_min_port=${FTP_PASV_MIN_PORT}
pasv_max_port=${FTP_PASV_MAX_PORT}
EOF

echo "[FTP] >> Starting vsftpd in foreground..."
exec /usr/sbin/vsftpd "$FTP_CONFIG_FILE"
