#!/bin/sh
set -e
TARGET_DIR="$1"

# Finding 3: BusyBox must not run as root for every user
chmod u-s "$TARGET_DIR/bin/busybox"

# Fail closed: no setuid/setgid file may remain in the image
LEFT="$(find "$TARGET_DIR" -type f -perm /6000)"
if [ -n "$LEFT" ]; then
    echo "ERROR: setuid/setgid files remain:" >&2
    echo "$LEFT" >&2
    exit 1
fi
