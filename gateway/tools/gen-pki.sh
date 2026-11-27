#!/bin/sh
# Lab PKI: one root CA, the broker certificate, one certificate per client.
# Output goes OUTSIDE the Git repository: private keys must never be committed.
set -e
OUT="${1:-$HOME/embarque/pki}"
mkdir -p "$OUT"
cd "$OUT"
umask 077                       # every file created here is readable by its owner only

# 1. Root CA (created once: its key is the root of trust)
if [ ! -f ca.key ]; then
    openssl ecparam -name prime256v1 -genkey -noout -out ca.key
    openssl req -x509 -new -key ca.key -sha256 -days 365 \
        -subj "/CN=Secure-IoT-Gateway Lab CA" -out ca.crt
fi

# 2. Broker certificate: names the client will check (SAN), server role only
openssl ecparam -name prime256v1 -genkey -noout -out broker.key
openssl req -new -key broker.key -subj "/CN=gateway" -out broker.csr
printf 'subjectAltName=DNS:gateway,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' > broker.ext
openssl x509 -req -in broker.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -days 365 -sha256 -extfile broker.ext -out broker.crt

# 3. Client certificates: the CN becomes the MQTT identity, client role only
printf 'extendedKeyUsage=clientAuth\n' > client.ext
for name in node1 monitor; do
    openssl ecparam -name prime256v1 -genkey -noout -out "$name.key"
    openssl req -new -key "$name.key" -subj "/CN=$name" -out "$name.csr"
    openssl x509 -req -in "$name.csr" -CA ca.crt -CAkey ca.key -CAcreateserial \
        -days 365 -sha256 -extfile client.ext -out "$name.crt"
done

rm -f ./*.csr ./*.ext
echo "PKI ready in $OUT"
