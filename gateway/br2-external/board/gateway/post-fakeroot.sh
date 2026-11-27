#!/bin/sh
set -e
TARGET_DIR="$1"
# The broker private key must be readable by the mosquitto user only
MQ_UID="$(awk -F: '$1=="mosquitto"{print $3}' "$TARGET_DIR/etc/passwd")"
MQ_GID="$(awk -F: '$1=="mosquitto"{print $4}' "$TARGET_DIR/etc/passwd")"
if [ -z "$MQ_UID" ]; then
    echo "ERROR: mosquitto user not found" >&2
    exit 1
fi
chown "$MQ_UID:$MQ_GID" "$TARGET_DIR/etc/mosquitto/certs/broker.key"
chmod 0400 "$TARGET_DIR/etc/mosquitto/certs/broker.key"

# Finding 3: BusyBox must not run as root for every user
chmod u-s "$TARGET_DIR/bin/busybox"

# Fail closed: no setuid/setgid file may remain in the image
LEFT="$(find "$TARGET_DIR" -type f -perm /6000)"
if [ -n "$LEFT" ]; then
    echo "ERROR: setuid/setgid files remain:" >&2
    echo "$LEFT" >&2
    exit 1
fi
