# Secure IoT Gateway

Personal project: **build, secure, then attack** an IoT system end to end — from an ESP32 field node to an embedded Linux gateway and a backend.

```
 ESP32 nodes (FreeRTOS)        Gateway (embedded Linux)          Backend
 sensors, Wi-Fi → LoRa   →     receives, checks, relays    →     containers on Proxmox
 secure boot, signed OTA       hardened: SELinux, nftables       storage, dashboards
            └──────────── mutual TLS (private PKI) ────────────┘
```

## Phases

| Phase | Content | Status | Details |
|---|---|---|---|
| A | Embedded Linux gateway built with Buildroot (ARM64), then hardened | In progress | [`gateway/`](gateway/) |
| B | ESP32 firmware with ESP-IDF: FreeRTOS, mutual TLS, signed OTA, secure boot | In progress | [`esp32-node/`](esp32-node/) |
| C | Attacking my own system: firmware extraction, UART access, network attacks — before/after hardening | Planned | — |
| D | Real gateway hardware, LoRa nodes, containerized backend, CRA-style documentation (threat model, SBOM) | Planned | — |

## Approach

Each phase starts by analyzing the default system **before any change**, lists its security findings, then fixes them one by one. Every protection is later tested by attacking it.
