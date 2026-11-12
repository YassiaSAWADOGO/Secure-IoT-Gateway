# Secure IoT Gateway — Phase A: Embedded Linux

Personal project: build, secure, then attack an IoT system end to end.
This phase covers the **base system of the gateway**: a minimal embedded Linux built with Buildroot, first explored in its default configuration, then hardened.

> \*\*Step 1\*\* — Build a first ARM64 embedded Linux, boot it under QEMU and analyze it \*\*before any modification\*\*.

\---

## Reproduce

```bash
git clone https://gitlab.com/buildroot.org/buildroot.git \&\& cd buildroot
git checkout 2025.02.19
make qemu\_aarch64\_virt\_defconfig
make
output/images/start-qemu.sh      # login: root ; clean shutdown: poweroff
```

Full configuration: [`buildroot.config`](buildroot.config)

\---

## 1\. What Buildroot built

|Property|Value|
|-|-|
|Buildroot|2025.02.19 (LTS branch)|
|Architecture|ARM64 (Cortex-A53)|
|C library|glibc|
|Kernel|Linux 6.12.27 (LTS branch), built with GCC 13.4.0|
|Root filesystem|ext4, 60 MB, of which **4 MB used**|

|Building block|Location|Notes|
|-|-|-|
|Cross-compilation toolchain|`output/host/`|`aarch64-buildroot-linux-gnu`: builds on an x86-64 Linux PC for an ARM64 Linux target. Its sysroot (`output/staging`) keeps development headers and libraries; the final rootfs only keeps what is needed at runtime.|
|Bootloader|—|None: QEMU loads the kernel directly.|
|Kernel|`output/images/Image` (12 MB)|Three times larger than the rest of the system.|
|Root filesystem|`output/images/rootfs.ext2` (60 MB)|Generated from `output/target/` (4.3 MB). Final ownership and permissions (root, setuid) are only applied when the image is created, through fakeroot. This image is QEMU's disk and keeps changes made at runtime.|

**Emulated machine:** generic ARM64 `virt` board, 1 core, 128 MB of RAM. The rootfs is exposed as a virtio disk (`/dev/vda`), the console is on the serial port (`ttyAMA0`).

\---

## 2\. From power-on to `login:`

```
QEMU (acts as bootloader) → kernel with "root=/dev/vda console=ttyAMA0"
  → discovers hardware through the device tree (serial port, disk, network)
  → mounts the rootfs read-only
  → starts init (BusyBox, PID 1), which reads /etc/inittab:
       ├─ mounts /proc, /sys, tmpfs; remounts / read-write
       ├─ rcS: starts services in order (S01 → S50)
       └─ getty on the serial console → "buildroot login:"
```

|Service|Role|
|-|-|
|`seedrng`|Seeds the kernel random number generator (essential for cryptography)|
|`syslogd`, `klogd`|System and kernel logs|
|`sysctl`|Kernel parameters (an entry point for hardening)|
|`network`|Networking via DHCP|
|`crond`|Scheduled tasks|

> Killing QEMU abruptly (Ctrl+A X) is equivalent to a power cut: on the next boot, ext4 has to replay its journal (`recovery required`). This is why embedded systems often use a read-only rootfs.

\---

## 3\. The system in numbers

|Metric|Value|
|-|-|
|Disk space used|4 MB (vs. more than 8 GB for the Debian development VM)|
|RAM used|11 MB|
|System commands|A single BusyBox binary (\~800 KB); every command is a symlink to it|
|Setuid files|1 (`/bin/busybox`)|
|Open network ports|0|

\---

## 4\. Security findings

|#|Finding|Planned fix|
|-|-|-|
|1|`root` has no password (empty field in `/etc/shadow`)|Strong password or locked account|
|2|Login prompt on the serial console (reachable through UART on real hardware)|Restrict in production|
|3|BusyBox is **setuid root**: an 800 KB binary that starts as root|Build BusyBox without setuid|
|4|`crond` running with no use|Remove the service|
|5|`/tmp` and `/dev/shm` mounted without `nosuid,nodev,noexec`|Add these options in `/etc/fstab`|
|6|Unused `dummy0` and `sit0` interfaces|Remove these features from the kernel|
|7|IPv6 enabled|Disable it or filter it in the firewall|
|8|Exact kernel version and build information readable by any user|Keep the kernel updated, reproducible build|

**Already good:** no open ports, system accounts without a login shell (`/bin/false`), a single setuid file.

\---

## 5\. Next steps

* \[ ] Integrate a C daemon as a Buildroot package (external tree, `BR2\_EXTERNAL`)
* \[ ] Fix findings 1 to 8
* \[ ] SELinux in enforcing mode, with a policy for the daemon
* \[ ] nftables firewall (IPv4 and IPv6)

\---

*References:* [*Buildroot manual*](https://buildroot.org/downloads/manual/manual.html) *· "Linux embarqué", Pierre Ficheux (Eyrolles)*

