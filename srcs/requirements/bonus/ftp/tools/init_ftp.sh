#!/bin/bash

# stop immediately if any command fails and if an undefined variable is used.
set -eu

FTP_ROOT="/var/www/html"
VSFTPD_CONFIG_FILE="/etc/vsftpd.conf"
VSFTPD_SECURE_DIR="/var/run/vsftpd/empty"

echo "[FTP] >> Verifying required Docker secrets..."

if [ -f /run/secrets/ftp_password ]; then
	FTP_PASSWORD=$(cat /run/secrets/ftp_password)
else
	echo "[ERROR] >> ftp_password secret not found."
	exit 1
fi

echo "[FTP] >> Creating required directories..."

mkdir -p "$FTP_ROOT"
mkdir -p "$VSFTPD_SECURE_DIR"

echo "[FTP] >> Configuring FTP user..."

# create the FTP user only if it doesn't exist. User's home dir is set to the WordPress dir allowing FTP access directly to the website files.
if ! id "$FTP_USER" >/dev/null 2>&1; then
	useradd -d "$FTP_ROOT" -s /bin/bash "$FTP_USER"

	# set the FTP user's password using the docker secret.
	echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd

	# add FTP user to the www-data group so it can access files shared with the WordPress service.
	usermod -aG www-data "$FTP_USER"
else
	echo "[FTP] >> FTP user already exists."
fi

echo "[FTP] >> Updating WordPress directory permissions..."

chown -R www-data:www-data "$FTP_ROOT"

# give the www-data group write permission, so that the FTP user can upload, modify and delete files through FTP.
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

echo "[FTP] >> Starting vsftpd in foreground..."

# start vsftpd in the foreground, exec replaces the Bash script with vsftpd, making it PID 1
exec vsftpd "$VSFTPD_CONFIG_FILE"
