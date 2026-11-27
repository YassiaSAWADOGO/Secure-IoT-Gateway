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

# Broker TLS material, read from the PKI kept outside Git (see tools/gen-pki.sh)
PKI_DIR="${GATEWAY_PKI_DIR:-$HOME/embarque/pki}"
for f in ca.crt broker.crt broker.key; do
    if [ ! -s "$PKI_DIR/$f" ]; then
        echo "ERROR: $PKI_DIR/$f is missing (run tools/gen-pki.sh)" >&2
        exit 1
    fi
done
install -d -m 0755 "$TARGET_DIR/etc/mosquitto/certs"
install -m 0644 "$PKI_DIR/ca.crt" "$PKI_DIR/broker.crt" "$TARGET_DIR/etc/mosquitto/certs/"
install -m 0600 "$PKI_DIR/broker.key" "$TARGET_DIR/etc/mosquitto/certs/broker.key"
