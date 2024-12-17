#!/usr/bin/env bash

# Replace set -e and exit with non-zero status if we experience a failure
trap 'exit' ERR

# Default location - overwritten with preceding path if one of them exists
MOSQUITTO_HOME=/var/dlmb

# Mosquitto configuration filename
MOSQUITTO_CONF=mosquitto.conf

# create this location if it doesn't exist
[ -d $MOSQUITTO_HOME ] || mkdir $MOSQUITTO_HOME

# Concat of path and configuration file
MOSQUITTO_PATH=$MOSQUITTO_HOME/$MOSQUITTO_CONF

# If file exists, move it to a timestamp-based name
if [ -f $MOSQUITTO_PATH ]; then
  rm $MOSQUITTO_PATH
	echo -n "Remove previous configuration."
fi

sed -Ee 's/^[ 	]+%%% //' <<!ENDMOSQUITTOCONF > $MOSQUITTO_PATH
	%%% include_dir /var/dlmb/conf.d
	%%% allow_anonymous false
	%%% autosave_interval 1800
	%%% connection_messages true
	%%% log_dest file /var/dlmb/log/mosquitto.log
	%%% log_dest topic
	%%% log_type error
	%%% log_type warning
	%%% log_type notice
	%%% log_type information
	%%% log_timestamp true
	%%% max_packet_size 10240000
	%%% persistence true
	%%% persistence_location /var/dlmb/data/
	%%% persistent_client_expiration 1m
	%%% retain_available true
	%%% # No TLS authentication
	%%% listener 1883
	%%% # Two-way TLS authentication
	%%% listener 8883
	%%% cafile /var/dlmb/ssl/ca.crt
	%%% certfile /var/dlmb/ssl/server.crt
	%%% keyfile /var/dlmb/ssl/server.key
	%%% require_certificate true
	%%% use_identity_as_username false
	%%% # One-way TLS authentication
	%%% listener 8884
	%%% cafile /var/dlmb/ssl/ca.crt
	%%% certfile /var/dlmb/ssl/server.crt
	%%% keyfile /var/dlmb/ssl/server.key
	%%% # WebSockets Connections
	%%% listener 8088
  %%% protocol websockets
	%%% # WebSockets TLS Connections
	%%% listener 9099
  %%% protocol websockets
	%%% cafile /var/dlmb/ssl/ca.crt
	%%% certfile /var/dlmb/ssl/server.crt
	%%% keyfile /var/dlmb/ssl/server.key
!ENDMOSQUITTOCONF

chmod 640 $MOSQUITTO_PATH