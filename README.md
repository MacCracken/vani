# Vani

> **Vani** (Sanskrit: वाणी — voice, speech. Saraswati's name — the goddess of knowledge, music, and art) — Audio device I/O for the Cyrius ecosystem. The voice of the system.

## What it does

- **PCM playback** — write audio samples to sound hardware via ALSA ioctls
- **PCM capture** — read audio samples from microphones / line-in
- **Format negotiation** — sample rate, channel count, bit depth, AlsaFormat
- **Ring buffer** — pow-of-two byte ring for jitter resilience
- **XRUN recovery** — re-prepare and retry on underrun / overrun
- **Mixer control** — `/dev/snd/controlC{N}` volume + mute (v0.3.0)
- **Multi-device** — onboard, USB, HDMI output selection (via yukti)

## Design

- **Direct ALSA ioctls** — no PulseAudio, no PipeWire, no middleware.
- **Single audio authority in stdlib** — vani owns the full stack
  from raw ALSA ioctls (`src/alsa.cyr`) up through typed errors,
  ring buffer, and XRUN recovery. Targeting cyrius 5.8.0 to retire
  the legacy `lib/audio.cyr` path; consumers will use
  `include "lib/vani.cyr"` for the entire audio surface.
- **yukti for discovery** — vani never scans `/dev/snd/` itself.
- **Integer PCM** — no floats in the sample path.

## Audio pipeline

```
Creation:   naad (synth) → dhvani (mix) → shravan (encode) → vani (→ speakers)
Capture:    vani (mic →) → shravan (decode) → dhvani (process)
```

vani is the boundary between digital audio and physical air.
Everything upstream is math. vani is hardware.

## Architecture

```
src/
  lib.cyr       — public include chain
  alsa.cyr      — raw ALSA PCM ioctls (audio_*)
  error.cyr     — VaniErr codes + Result helpers
  format.cyr    — sample format struct + frame/byte math
  buffer.cyr    — pow-of-2 ring buffer
  device.cyr    — VaniDevice handle (wraps alsa.cyr)
  playback.cyr  — write path with XRUN recovery
  capture.cyr   — read path with XRUN recovery
  mixer.cyr     — control device (volume / mute)
```

## Layered model

```
yukti scans /dev/snd/ and /proc/asound/
  → returns audio device descriptors (card, device, subdevice, capabilities)
    → vani opens the device handle (vani_open_playback / vani_open_capture)
      → vani configures format via audio_set_params (stdlib audio.cyr)
        → vani_play / vani_record move PCM frames in or out
          → on XRUN → audio_prepare → retry
```

## Hardware targets

| Device | Interface | Notes |
|--------|-----------|-------|
| Onboard audio | ALSA PCM | Most common, always available |
| USB audio interface | ALSA USB-audio | Pro audio, low latency |
| HDMI audio | ALSA HDMI | Display audio output |
| 3.5mm jack (RPi4) | ALSA BCM2835 | Headphone / speaker out |
| Bluetooth audio | future | needs BT stack |

## Consumers

| Project | Usage |
|---------|-------|
| **shravan** | Decoded audio → vani for playback |
| **dhvani** | Mixed / processed audio → vani output |
| **naad** | Synthesized audio → vani output |
| **jalwa** | Music player → vani for playback |
| **shruti** | DAW — playback + capture through vani |
| **cyrius-doom** | Game audio (upgrade from PC speaker) |
| **agnoshi** | Voice input / output for AI shell |

## Build

```bash
cyrius deps                                       # populate lib/ from stdlib
cyrius build programs/smoke.cyr build/vani_smoke  # link-check
cyrius test tests/tcyr/vani.tcyr                  # CPU suite
cyrius distlib                                    # → dist/vani.cyr
```

## License

GPL-3.0-only

## Project

Part of [AGNOS](https://agnosticos.org) — the AI-native operating system.
