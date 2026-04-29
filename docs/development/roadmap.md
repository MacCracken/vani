# Vani Development Roadmap

> **v0.1.0** — Scaffolded. Audio device I/O for Cyrius.

## v0.1.0 — Foundation

| # | Item | Status |
|---|------|--------|
| 1 | ALSA ioctl constants and structs | Not started |
| 2 | Device open/close (pcmC*D*p) | Not started |
| 3 | HW params negotiation (format, rate, channels) | Not started |
| 4 | Basic PCM write (blocking) | Not started |
| 5 | Play a WAV file from shravan decode | Not started |

## v0.2.0 — Capture + Buffering

| # | Item | Status |
|---|------|--------|
| 1 | PCM capture (microphone input) | Not started |
| 2 | Ring buffer with configurable latency | Not started |
| 3 | Underrun/overrun detection and recovery | Not started |

## v0.3.0 — Mixer + Multi-device

| # | Item | Status |
|---|------|--------|
| 1 | Hardware mixer (volume, mute) via ALSA mixer ioctls | Not started |
| 2 | Multi-device selection (onboard, USB, HDMI) | Not started |
| 3 | yukti integration for device discovery | Not started |

## v1.0.0 — Stable

| # | Item | Status |
|---|------|--------|
| 1 | lib/vani.cyr stdlib distribution | Not started |
| 2 | Tested on 3+ hardware targets | Not started |
| 3 | Benchmarks: latency, throughput | Not started |
| 4 | DOOM audio upgrade (PC speaker → real audio) | Not started |
