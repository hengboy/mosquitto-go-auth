#!/usr/bin/env bash

# init auth.conf
bash /usr/local/shell/auth-setup.sh
rm -rf /usr/local/shell/auth-setup.sh

# startup mosquitto
/usr/sbin/mosquitto -c /var/mosquitto/mosquitto.conf