Secure IoT Gateway — Embedded Linux

Personal project: build, secure, then attack an IoT system end to end. This part covers the gateway: a minimal embedded Linux built with Buildroot, first analyzed in its default configuration, then hardened step by step.

Step	Content	Status
1	Build a default ARM64 embedded Linux and analyze it before any change	Done
2	Buildroot external tree and first daemon (gatewayd)	Done
3	Hardening: fix every security finding, measured before/after	In progress
Reproduce
bash
# Buildroot (LTS branch)
git clone https://gitlab.com/buildroot.org/buildroot.git && cd buildroot
git checkout 2025.02.19

# Root password: only its hash is used, kept outside Git
openssl passwd -6 > <path>/gateway/br2-external/board/gateway/root-passwd-hash

# Configure with the external tree, then build
make BR2_EXTERNAL=<path>/gateway/br2-external gateway_defconfig
make

# Boot (clean shutdown: poweroff)
output/images/start-qemu.sh

The build fails on purpose if root-passwd-hash is missing.

Step 1 — What Buildroot built
Property	Value
Buildroot	2025.02.19 (LTS branch)
Architecture	ARM64 (Cortex-A53)
C library	glibc
Kernel	Linux 6.12.27 (LTS branch), built with GCC 13.4.0
Root filesystem	ext4, 60 MB, of which 4 MB used
Building block	Location	Notes
Cross-compilation toolchain	output/host/	aarch64-buildroot-linux-gnu: builds on an x86-64 Linux PC for an ARM64 Linux target. Its sysroot (output/staging) keeps development headers and libraries; the final rootfs only keeps what is needed at runtime.
Bootloader	—	None: QEMU loads the kernel directly.
Kernel	output/images/Image (12 MB)	Three times larger than the rest of the system.
Root filesystem	output/images/rootfs.ext2 (60 MB)	Generated from output/target/ (4.3 MB). Final ownership and permissions (root, setuid) are only applied when the image is created, through fakeroot. This image is QEMU's disk and keeps changes made at runtime.

Emulated machine: generic ARM64 virt board, 1 core, 128 MB of RAM. The rootfs is exposed as a virtio disk (/dev/vda), the console is on the serial port (ttyAMA0).

From power-on to login:
QEMU (acts as bootloader) → kernel with "root=/dev/vda console=ttyAMA0"
  → discovers hardware through the device tree (serial port, disk, network)
  → mounts the rootfs read-only
  → starts init (BusyBox, PID 1), which reads /etc/inittab:
       ├─ mounts /proc, /sys, tmpfs; remounts / read-write
       ├─ rcS: starts services in order (S01 → S90)
       └─ getty on the serial console → "buildroot login:"
Service	Role
seedrng	Seeds the kernel random number generator (essential for cryptography)
syslogd, klogd	System and kernel logs
sysctl	Kernel parameters (an entry point for hardening)
network	Networking via DHCP
crond	Scheduled tasks

Killing QEMU abruptly (Ctrl+A X) is equivalent to a power cut: on the next boot, ext4 has to replay its journal (recovery required). This is why embedded systems often use a read-only rootfs.

Step 2 — External tree and first daemon

My own code lives in a Buildroot external tree (br2-external/), outside the Buildroot sources: Buildroot stays untouched and everything specific to the gateway is versioned here.

br2-external/
├── external.desc            # name: GATEWAY → defines BR2_EXTERNAL_GATEWAY_PATH
├── Config.in                # adds the package to menuconfig
├── external.mk              # includes every package recipe
├── configs/gateway_defconfig
├── board/gateway/           # post-build.sh (secrets stay git-ignored)
├── package/gatewayd/        # Config.in, gatewayd.mk (generic-package), S90gatewayd
└── src/gatewayd/            # gatewayd.c, Makefile

gatewayd is a minimal daemon: it logs to syslog every 10 seconds and stops cleanly on SIGTERM. Its Makefile never hardcodes gcc: Buildroot passes its cross-compiler and flags through $(TARGET_CONFIGURE_OPTS), so the same source builds for the host (quick tests) and for the ARM64 target.

S90gatewayd starts it at boot after the network (S40network), using BusyBox start-stop-daemon and a PID file; stop sends SIGTERM.

Starting network: OK
Starting crond: OK
Starting gatewayd: OK
Step 3 — Hardening (in progress)

Baseline, before hardening:

Metric	Before
Kernel	12 MB
Root filesystem	4.3 MB
BusyBox commands	279, setuid root
Boot scripts	7, of which 5 resident daemons
RAM used	11 MB
Open ports	0
Network interfaces	4 (lo, eth0, dummy0, sit0), IPv6 enabled

Fixes so far:

#	Fix	How it is verified
9	GATEWAYD_USERS creates a locked system user; the init script starts the daemon with start-stop-daemon -c gatewayd	ps shows gatewayd, not root, as the process owner
1	A SHA-512 hash (openssl passwd -6) lives in a git-ignored file; post-build.sh writes it into /etc/shadow and fails the build if it is missing (fail closed)	Login asks for a password; a wrong one is rejected
Security findings
#	Finding	Status / planned fix
1	root has no password (empty field in /etc/shadow)	✅ Fixed: password hash kept outside Git, written into /etc/shadow by a post-build script (the build fails if it is missing)
2	Login prompt on the serial console (reachable through UART on real hardware)	Restrict in production
3	BusyBox is setuid root: an 800 KB binary that starts as root	Build BusyBox without setuid
4	crond running with no use	Remove the service
5	/tmp and /dev/shm mounted without nosuid,nodev,noexec	Add these options in /etc/fstab
6	Unused dummy0 and sit0 interfaces	Remove these features from the kernel
7	IPv6 enabled	Disable it or filter it in the firewall
8	Exact kernel version and build information readable by any user	Keep the kernel updated, reproducible build
9	gatewayd runs as root: once it parses network data, any exploitable bug gives full control of the gateway	✅ Fixed: dedicated gatewayd user (no shell, no password); SELinux confinement planned

Already good: no open ports, system accounts without a login shell (/bin/false), a single setuid file.

Next steps
[x] Integrate a C daemon as a Buildroot package (external tree, BR2_EXTERNAL)
[ ] Fix findings 2 to 8
[ ] SELinux in enforcing mode, with a policy for the daemon
[ ] nftables firewall (IPv4 and IPv6)

References: Buildroot manual · "Linux embarqué", Pierre Ficheux (Eyrolles)
