#!/bin/bash
set -e

FTP_PASSWORD=$(cat /run/secrets/ftp_password)

# Guarded, so restarting the container does not try to create the account twice.
if ! id "$FTP_USER" > /dev/null 2>&1; then

	useradd --no-create-home \
		--home-dir /var/www/html \
		--gid www-data \
		--shell /bin/bash \
		"$FTP_USER"

	echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
fi

# The volume belongs to www-data, whose group must be able to write for uploads.
chmod g+w /var/www/html

exec "$@"
