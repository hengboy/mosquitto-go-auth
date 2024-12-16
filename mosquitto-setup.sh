#!/usr/bin/env bash
#(@)mosquitto-setup.sh - Create a basic Mosquitto configuration w/ TLS

# Replace set -e and exit with non-zero status if we experience a failure
trap 'exit' ERR

# Default location - overwritten with preceding path if one of them exists
MOSQHOME=/var/mosquitto

# Mosquitto configuration filename
MOSQCONF=mosquitto.conf

# create this location if it doesn't exist
[ -d $MOSQHOME ] || mkdir $MOSQHOME

# Concat of path and configuration file
MOSQPATH=$MOSQHOME/$MOSQCONF

# If file exists, move it to a timestamp-based name
if [ -f $MOSQPATH ]; then
  rm $MOSQPATH
	echo -n "Remove previous configuration."
fi

sed -Ee 's/^[ 	]+%%% //' <<!ENDMOSQUITTOCONF > $MOSQPATH
	%%% include_dir /var/mosquitto/conf.d
	%%% 
	%%% allow_anonymous false
	%%% autosave_interval 1800
	%%% 
	%%% connection_messages true
	%%% log_dest file /var/mosquitto/log/mosquitto.log
	%%% log_dest topic
	%%% log_type error
	%%% log_type warning
	%%% log_type notice
	%%% log_type information
	%%% log_type all
	%%% log_type debug
	%%% log_timestamp true
	%%% 
	%%% max_packet_size 10240000
	%%% 
	%%% persistence true
	%%% persistence_location /var/mosquitto/data/
	%%% persistent_client_expiration 1m
	%%% 
	%%% retain_available true
	%%% 
	%%% # No TLS authentication
	%%% listener 1883
	%%% 
	%%% # Two-way TLS authentication
	%%% listener 8883
	%%% cafile /var/mosquitto/ssl/ca.crt
	%%% certfile /var/mosquitto/ssl/server.crt
	%%% keyfile /var/mosquitto/ssl/server.key
	%%% require_certificate true
	%%% use_identity_as_username false
	%%% 
	%%% # One-way TLS authentication
	%%% listener 8884
	%%% cafile /var/mosquitto/ssl/ca.crt
	%%% certfile /var/mosquitto/ssl/server.crt
	%%% keyfile /var/mosquitto/ssl/server.key
!ENDMOSQUITTOCONF

chmod 640 $MOSQPATH