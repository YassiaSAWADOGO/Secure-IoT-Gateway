#!/bin/sh
# Boot the gateway under QEMU, with the MQTT port forwarded from the host.
# Usage: run-qemu.sh [buildroot output/images directory]
set -e
IMAGES="${1:-$HOME/embarque/buildroot/output/images}"
cd "$IMAGES"
exec qemu-system-aarch64 -M virt -cpu cortex-a53 -nographic -smp 1 \
    -kernel Image -append "rootwait root=/dev/vda console=ttyAMA0" \
    -netdev user,id=eth0,hostfwd=tcp:127.0.0.1:8883-:8883 \
    -device virtio-net-device,netdev=eth0 \
    -drive file=rootfs.ext4,if=none,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0
