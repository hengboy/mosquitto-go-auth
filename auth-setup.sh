#!/usr/bin/env bash
#(@)mosquitto-setup.sh - Create a basic Mosquitto configuration w/ TLS

# Replace set -e and exit with non-zero status if we experience a failure
trap 'exit' ERR
# Default location - overwritten with preceding path if one of them exists
MOSQCONF=/var/mosquitto/conf.d

# Mosquitto configuration filename
AUTHCONF=auth.conf

# Concat of path and configuration file
AUTHPATH=$MOSQCONF/$AUTHCONF

# If file exists, move it to a timestamp-based name
if [ -f $AUTHPATH ]; then
  rm $AUTHPATH
	echo "Remove previous configuration."
fi

sed -Ee 's/^[ 	]+%%% //' <<!ENDMOSQUITTOCONF > $AUTHPATH
	%%% auth_plugin /var/mosquitto/plugins/go-auth.so
	%%% auth_opt_backends mysql
	%%% # Hashing
	%%% auth_opt_hasher argon2id
	%%% auth_opt_hasher_salt_size 16
	%%% auth_opt_hasher_iterations 3
	%%% auth_opt_hasher_keylen 64
	%%% auth_opt_hasher_memory 4096
	%%% auth_opt_hasher_parallelism 2
	%%% # MySQL
	%%% auth_opt_mysql_host $DLMB_MYSQL_HOST
	%%% auth_opt_mysql_port $DLMB_MYSQL_PORT
	%%% auth_opt_mysql_dbname $DLMB_MYSQL_DB
	%%% auth_opt_mysql_user $DLMB_MYSQL_USERNAME
	%%% auth_opt_mysql_password $DLMB_MYSQL_PASSWORD
	%%% auth_opt_mysql_allow_native_passwords true
	%%% auth_opt_mysql_userquery SELECT password_hash FROM mosquitto_user WHERE username = ? limit 1
	%%% auth_opt_mysql_superquery SELECT COUNT(1) FROM mosquitto_user WHERE username = ? AND is_admin = 1 LIMIT 1
	%%% auth_opt_mysql_aclquery SELECT topic FROM mosquitto_acl acl inner join mosquitto_user user on acl.mosquitto_user_id = user.id WHERE user.username = ? AND acl.rw = ?
!ENDMOSQUITTOCONF

chmod 640 $AUTHPATH
echo "Configuration file generated successfully, location: $AUTHPATH"