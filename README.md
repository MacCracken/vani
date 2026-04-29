# Vani

> **Vani** (Sanskrit: वाणी — voice, speech. Saraswati's name — the goddess of knowledge, music, and art) — Audio device I/O for the Cyrius ecosystem. The voice of the system.

## What It Does

- **PCM playback** — write audio samples to sound hardware
- **PCM capture** — read audio samples from microphones/line-in
- **Device management** — open, configure, close audio devices (via yukti for discovery)
- **Format negotiation** — query device capabilities, match to source PCM format
- **Buffer management** — configurable ring buffers, latency control
- **Multi-device** — onboard, USB, HDMI audio output selection

## Design

- **Direct ALSA ioctls** — no PulseAudio, no PipeWire daemon, no middleware
- **yukti for device discovery** — vani receives device handles, doesn't scan hardware itself
- **Zero external dependencies** — pure Cyrius, direct syscalls via agnosys
- **Stdlib integration** — `lib/vani.cyr` for basic playback, full crate for advanced features

## Audio Pipeline

```
Creation:   naad (synthesis) → dhvani (process/mix) → shravan (encode) → vani (→ speakers)
Capture:    vani (mic →) → shravan (decode) → dhvani (process)
```

vani is the boundary between digital audio and physical air. Everything upstream is math. vani is hardware.

## Architecture

```
src/
  lib.cyr       — public API
  device.cyr    — ALSA device open/close/configure via ioctls
  playback.cyr  — PCM write path, ring buffer, underrun handling
  capture.cyr   — PCM read path, ring buffer, overrun handling
  format.cyr    — sample format negotiation (rate, channels, bit depth)
  buffer.cyr    — ring buffer management, latency configuration
  mixer.cyr     — hardware mixer controls (volume, mute) via ALSA mixer ioctls
```

## Integration with yukti

```
yukti scans /dev/snd/ and /proc/asound/
  → returns audio device descriptors (card, device, subdevice, capabilities)
    → vani opens the device handle
      → vani configures format via ioctl
        → vani writes/reads PCM samples
```

vani never scans for hardware. yukti finds it. vani uses it.

## Hardware Targets

| Device | Interface | Notes |
|--------|-----------|-------|
| Onboard audio | ALSA PCM | Most common, always available |
| USB audio interface | ALSA USB-audio | Pro audio, low latency |
| HDMI audio | ALSA HDMI | Display audio output |
| 3.5mm jack (RPi4) | ALSA BCM2835 | Headphone/speaker out |
| Bluetooth audio | Future | Needs BT stack |

## Consumers

| Project | Usage |
|---------|-------|
| **shravan** | Decoded audio → vani for playback |
| **dhvani** | Mixed/processed audio → vani output |
| **naad** | Synthesized audio → vani output |
| **jalwa** | Music player → vani for playback |
| **shruti** | DAW — playback + capture through vani |
| **cyrius-doom** | Game audio (upgrade from PC speaker) |
| **agnoshi** | Voice input/output for AI shell |

## Build

```
cyrius build
```

## License

GPL-3.0-only

## Project

Part of [AGNOS](https://agnosticos.org) — the AI-native operating system.
