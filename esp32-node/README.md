# ESP32 Node — Phase B: Firmware with ESP-IDF

Field node of the secure IoT system: an ESP32 running FreeRTOS that will publish its measurements to the gateway over mutually authenticated TLS.

> **Step 1** — Set up the toolchain, understand the anatomy of an ESP-IDF project, build and flash a first firmware, and observe the ESP32 boot chain.

---

## Environment

| Item | Value |
|---|---|
| Framework | ESP-IDF v6.0.2 |
| Target | `esp32` — Xtensa toolchain `xtensa-esp-elf` (bare metal: no OS underneath, FreeRTOS is linked into the firmware) |
| Flashing tool | esptool v5.6.0 |
| Chip | **ESP32-D0WD, revision v1.0**, dual core 240 MHz, Wi-Fi + BT |
| USB-serial bridge | CH340 (`/dev/ttyUSB0`, `ch341` driver) |
| Host | Debian VM (VirtualBox, USB passthrough); user added to the `dialout` group to access the serial port without root (least privilege) |

---

## Hardware assessment

Checking the chip revision came first, because it decides which security features are available:

- **Secure Boot v2 requires revision v3.0 or later.** This chip (v1.0) only supports the older Secure Boot v1.
- Early ESP32 revisions are known to be **vulnerable to fault injection** (voltage glitching), which can bypass secure boot and flash encryption. This was addressed in revision v3.0.

| Board | Role |
|---|---|
| ESP32 rev v1.0 (this board) | All of Phase B except secure boot; then the **vulnerable reference target** for Phase C |
| ESP32-C3 or S3 (to come) | Secure Boot v2 and flash encryption |

---

## Reproduce

```bash
. ~/esp/esp-idf/export.sh
cd 01-hello
idf.py set-target esp32
idf.py build
idf.py -p /dev/ttyUSB0 flash monitor    # exit: Ctrl+T then Ctrl+X
```

`01-hello` starts from Espressif's `hello_world` example. My configuration choices are kept in `sdkconfig.defaults`.

---

## From source to flash

**Minimal project:** a root `CMakeLists.txt` (the project), a `main/CMakeLists.txt` (the `main` component) and a C file defining `app_main()`. Everything in ESP-IDF is a component; this hello world already pulls in 51 of them. `app_main()` is not the real entry point: it runs as a FreeRTOS task once the system is up.

**Build outputs and flash layout:**

| Address | Content | Size |
|---|---|---|
| `0x1000` | Second-stage bootloader | 26 KB |
| `0x8000` | Partition table | 3 KB |
| `0x10000` | Application (`factory` partition, 1 MB) | 121 KB |

The `.elf` file (2.4 MB, with symbols) stays on the host for debugging; only the raw `.bin` image is written to flash.

**Memory usage:** 43 KB of code executed from flash, 42 KB of IRAM out of 128 KB, 12.6 KB of DRAM out of 180 KB. For comparison, the Linux gateway uses 11 MB of RAM.

**Boot chain observed in the serial monitor:**

```
ROM (fixed in silicon) → bootloader at 0x1000 → partition table at 0x8000
  → application at 0x10000 → ESP-IDF startup (CPU, heap, FreeRTOS) → app_main()
```

Same principle as the Linux gateway (ROM → bootloader → system → first program), at a much smaller scale.

---

## Security findings

| # | Finding | Planned fix |
|---|---|---|
| 1 | The app image carries a SHA-256 hash checked by the bootloader: this guarantees **integrity, not authenticity** — anyone can compute it for their own firmware | Signed images (Secure Boot v2) on the second board; signed OTA updates |
| 2 | The flash is an **external chip**, readable over USB or after desoldering: code and any stored secret are in plaintext | Flash encryption (key kept in eFuses) |
| 3 | Debug logs are sent **in plaintext over UART** | Lower log level for production; never log secrets |
| 4 | Security options live in `sdkconfig` and burn eFuses **irreversibly** | Always verify them in `sdkconfig` (`grep`), never only in the menuconfig UI |
| 5 | Single application partition: no update path | Two OTA partitions (after checking the actual flash size) |

---

## Next steps

- [ ] FreeRTOS tasks, queues and synchronization
- [ ] Peripheral driver for a real sensor, written from its datasheet
- [ ] Wi-Fi station with reliable reconnection
- [ ] MQTT, then mutual TLS with a private PKI
- [ ] Signed OTA updates

---

*References: [ESP-IDF Programming Guide (v6.0)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/)*
