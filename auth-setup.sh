#!/usr/bin/env bash

# Replace set -e and exit with non-zero status if we experience a failure
trap 'exit' ERR

# Default location - overwritten with preceding path if one of them exists
MOSQUITTO_CONF=/var/dlmb/conf.d

# Mosquitto configuration filename
AUTH_CONF=auth.conf

# Concat of path and configuration file
AUTH_PATH=$MOSQUITTO_CONF/$AUTH_CONF

# If file exists, move it to a timestamp-based name
if [ -f $AUTH_PATH ]; then
  rm $AUTH_PATH
	echo "Remove previous configuration."
fi

sed -Ee 's/^[ 	]+%%% //' <<!ENDMOSQUITTOCONF > $AUTH_PATH
	%%% auth_plugin /var/dlmb/plugins/go-auth.so
	%%% auth_opt_backends mysql
	%%% # Hashing
	%%% auth_opt_hasher $DLMB_AUTH_HASHER
	%%% auth_opt_hasher_salt_size $DLMB_AUTH_HASHER_SALT_SIZE
	%%% auth_opt_hasher_iterations $DLMB_AUTH_HASHER_ITERATIONS
	%%% auth_opt_hasher_keylen $DLMB_AUTH_HASHER_KEYLEG
	%%% auth_opt_hasher_memory $DLMB_AUTH_HASHER_MEMORY
	%%% auth_opt_hasher_parallelism $DLMB_AUTH_HASHER_PARALLELISM
	%%% # MySQL
	%%% auth_opt_mysql_host $DLMB_MYSQL_HOST
	%%% auth_opt_mysql_port $DLMB_MYSQL_PORT
	%%% auth_opt_mysql_dbname $DLMB_MYSQL_DB
	%%% auth_opt_mysql_user $DLMB_MYSQL_USERNAME
	%%% auth_opt_mysql_password $DLMB_MYSQL_PASSWORD
	%%% auth_opt_mysql_allow_native_passwords true
	%%% auth_opt_mysql_userquery SELECT password_hash FROM mqtt_broker_user WHERE username = ? limit 1
	%%% auth_opt_mysql_superquery SELECT COUNT(1) FROM mqtt_broker_user WHERE username = ? AND is_admin = 1 LIMIT 1
	%%% auth_opt_mysql_aclquery SELECT topic FROM mqtt_broker_acl acl inner join mqtt_broker_user user on acl.user_id = user.id WHERE user.username = ? AND acl.rw = ?
!ENDMOSQUITTOCONF

chmod 640 $AUTH_PATH
echo "Configuration file generated successfully, location: $AUTH_PATH"