#!/usr/bin/env bash

AUTH_SETUP_SH=/usr/local/shell/auth-setup.sh
# init auth.conf
if [ -f $AUTH_SETUP_SH ]; then
  bash $AUTH_SETUP_SH
  rm -rf $AUTH_SETUP_SH
fi

# startup mosquitto
/usr/sbin/mosquitto -c /var/dlmb/mosquitto.conf