#!/bin/bash

set -e

DB_HOST=mariadb
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER
DB_PASSWORD=$(cat /run/secrets/db_password)
source /run/secrets/credentials



counter=0
while ! (exec 3<>/dev/tcp/$DB_HOST/3306) 2>/dev/null && (($counter<20)) ; do
	echo "Waiting for Mariadbd setup to finish..."
	sleep 1
	counter=$((counter+1))
done

if (( counter >= 20 )); then
    echo "mariadb never became reachable, giving up" >&2
    exit 1
fi

if [ ! -f "/var/www/html/wp-config.php" ]; then
	
	wp config create \
	--dbname=${DB_NAME} \
	--dbuser=${DB_USER} \
	--dbpass=${DB_PASSWORD} \
	--dbhost=${DB_HOST} \
	--allow-root

	wp core install \
	--url=https://sel-jari.42.fr \
	--title="Inception" \
	--admin_user=saad \
	--admin_password=$ADMIN_PASSWORD \
	--admin_email=admin@example.com \
	--allow-root

	wp user create simo \
	simo@gmail.com \
	--user_pass=$USER_PASSWORD \
	--allow-root

fi
exec "$@"
