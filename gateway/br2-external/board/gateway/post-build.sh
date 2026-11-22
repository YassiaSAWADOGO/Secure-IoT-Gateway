#!/bin/sh
# Buildroot post-build script: runs after the target filesystem is assembled,
# before the images are created. $1 is the target directory (output/target).
set -e

TARGET_DIR="$1"
HASH_FILE="$(dirname "$0")/root-passwd-hash"

# Root password: insert the hash kept outside Git. Fail if it is missing,
# instead of shipping an image with a passwordless root account.
if [ ! -s "$HASH_FILE" ]; then
    echo "ERROR: $HASH_FILE is missing (generate it with: openssl passwd -6)" >&2
    exit 1
fi
HASH="$(cat "$HASH_FILE")"
sed -i "s|^root:[^:]*:|root:${HASH}:|" "$TARGET_DIR/etc/shadow"
