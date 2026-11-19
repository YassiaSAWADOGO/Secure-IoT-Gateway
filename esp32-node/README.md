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
| 5 | Single application partition: no update path | Two OTA partitions (4 MB flash: ~1.9 MB each) |

---

## Next steps

- [x] FreeRTOS tasks and queues
- [ ] Mutex (shared resource protection)
- [ ] Peripheral driver for a real sensor, written from its datasheet
- [ ] Wi-Fi station with reliable reconnection
- [ ] MQTT, then mutual TLS with a private PKI
- [ ] Signed OTA updates

---

*References: [ESP-IDF Programming Guide (v6.0)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/)*

---

## Step 2 — FreeRTOS: priorities and queues

### `02-tasks`: priorities and starvation

Two tasks pinned to core 0. `rapide` (priority 6) first used a **busy wait** (`esp_rom_delay_us`), which never gives the CPU back:

```
I (14788) prio: Rapide : tour 29
E (15258) task_wdt: Task watchdog got triggered. The following tasks/users did not reset the watchdog in time:
E (15258) task_wdt:  - IDLE0 (CPU 0)
E (15258) task_wdt: CPU 0: rapide
E (15258) task_wdt: CPU 1: IDLE1
```

`lente` was never even created: `app_main` (priority 1, core 0) stayed preempted by `rapide`. The task watchdog detected that the idle task of core 0 could not run.

With a **blocking delay** (`vTaskDelay`), both tasks run: each one sleeps on its own timer, and priority only matters when several tasks are ready at the same time.

```
I (258) prio: Rapide : tour 0
I (258) prio: Lente : tour 0
I (268) main_task: Returned from app_main()
I (2258) prio: Rapide : tour 4
I (2268) prio: Lente : tour 1
```

**Takeaway:** a high-priority task must block regularly, otherwise it starves every lower-priority task on its core, including `app_main`.

### `03-queue`: producer / consumer

A `capteur` task produces one measurement per second; an `envoi` task consumes one every 2.5 s (simulated slow network). They communicate through a 5-slot queue that **copies** each measurement.

```
I (7768) queue: Envoi : mesure 3 envoyée (29.3 °C), 4 en attente
I (8268) queue: Capteur : mesure 8 déposée (26.7 °C)
W (9368) queue: Capteur : file pleine, mesure 9 PERDUE
I (10268) queue: Envoi : mesure 4 envoyée (29.3 °C), 4 en attente
```

**Takeaway:** when the producer is faster than the consumer, the queue fills up and data is lost. Queue size and task rates must be designed together — a real question for the node when Wi-Fi drops: how many measurements should be kept until it comes back?
