# Vani

> **Vani** (Sanskrit: वाणी — voice, speech. Saraswati's name — the goddess of knowledge, music, and art) — Audio device I/O for the Cyrius ecosystem. The voice of the system.

## What it does

- **PCM playback** — write audio samples to sound hardware via ALSA ioctls
- **PCM capture** — read audio samples from microphones / line-in
- **Format negotiation** — sample rate, channel count, bit depth, AlsaFormat
- **Ring buffer** — pow-of-two byte ring for jitter resilience
- **XRUN recovery** — re-prepare and retry on underrun / overrun
- **Mixer control** — `/dev/snd/controlC{N}` volume + mute
- **Multi-device** — onboard, USB, HDMI output selection (via yukti)
- **Non-blocking sink** — `audio_write_nb` / `audio_avail` for cooperative
  multi-process mixing (agnos; Linux delegates to the blocking write)
- **Two distribution profiles** — the full `vani_*` surface, or a
  playback-only `audio_*` core bundle for consumers that just need
  open / write / drain / close

## Design

- **Direct ALSA ioctls** — no PulseAudio, no PipeWire, no middleware.
- **Single audio authority in stdlib** — vani owns the full stack from
  raw ALSA ioctls (`src/alsa.cyr`) up through typed errors, ring buffer
  and XRUN recovery. Cyrius bundles vani as `lib/vani.cyr`, so
  `include "lib/vani.cyr"` gets the entire audio surface. The legacy
  stdlib `lib/audio.cyr` path is retired and gone.
- **yukti for discovery** — vani never scans `/dev/snd/` itself.
- **Integer PCM** — no floats in the sample path.

## Audio pipeline

```
Playback    naad (synth) ──────────────┐
                                       ├──> dhvani (mix) ──> vani ──> speakers
            shravan (decode a file) ───┘

Capture     mic ──> vani ──> dhvani (process) ──> shravan (encode a file)
```

vani moves **PCM only**, in both directions. Codecs are shravan's job;
vani never sees an encoded stream.

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
    → vani opens the device handle (vani_open_playback / vani_open_capture
      / vani_open_yukti)
      → vani configures the format via audio_set_params_fmt (src/alsa.cyr)
        → vani_play / vani_record move PCM frames in or out
          → on XRUN → prepare → retry once; on disconnect → fail, no retry
```

## Hardware targets

All of these are the same code path — vani has no per-device branching
below the yukti descriptor. The distinction is what has actually been
*run on hardware*, which is narrower than what is expected to work:

| Device | Interface | Status |
|--------|-----------|--------|
| Onboard analog (HDA / ALC897) | ALSA PCM | **Verified, audible** — cyrius-doom, 2026-06-29 |
| HDMI audio | ALSA HDMI | Enumerated by `vani_devices`; never round-tripped |
| USB audio interface | ALSA USB-audio | Not yet tested — no hardware access |
| 3.5mm jack (RPi4) | ALSA BCM2835 | Not yet tested |
| Bluetooth audio | — | Out of scope; needs a BT stack above vani |

Hardware coverage is tracked in
[`docs/development/roadmap.md`](docs/development/roadmap.md); what has
been verified and when is in
[`docs/development/state.md`](docs/development/state.md).

## Consumers

Live — these call vani today:

| Project | Profile | Usage |
|---------|---------|-------|
| **dhvani** | full | AGNOS audio engine. Bridges its f64 buffers to vani's interleaved PCM — the deepest `vani_*` exerciser and the consumer that validates the full frozen surface. |
| **cyrius-doom** | core | Game audio. 24 `audio_*` symbols, the deepest core exerciser. First consumer confirmed **audible on real hardware**. |
| **jalwa** | core (via dhvani) | Music player. Reaches the `audio_*` shim through dhvani's bundle rather than depending on vani directly. |
| **mishran** | core | AGNOS software mixer / routing daemon. Fans many per-app streams into one vani sink. |
| **cyrius-polyomino** | core | Game SFX. |
| **cyrius-bb** | core | Game SFX. |

Planned, not yet integrated — listed because the pipeline above implies
them, but **no code calls vani yet**: **shravan** (decode → playback),
**naad** (synthesis; currently reaches hardware via dhvani), **shruti**
(DAW capture + playback), **agnoshi** (voice I/O).

Current versions and per-consumer detail live in
[`docs/development/state.md`](docs/development/state.md).

## Build

```bash
cyrius deps                                       # populate lib/ from the pinned snapshot
cyrius build programs/smoke.cyr build/vani_smoke  # link-check
cyrius test tests/tcyr/vani.tcyr                  # CPU suite
cyrius bench tests/bcyr/vani.bcyr                 # CPU benches
cyrius distlib && cyrius distlib core             # → dist/vani.cyr, dist/vani-core.cyr
```

The toolchain version is pinned by `cyrius = "X.Y.Z"` in `cyrius.cyml`
and nowhere else; CI and the release workflow both read it from there.
Targets built and gated: `x86_64-linux`, `aarch64-linux`, `agnos`.
Windows/PE is explicitly **not** supported — see
[ADR 0003](docs/adr/0003-no-windows-pe-target.md).

## License

GPL-3.0-only

## Project

Part of [AGNOS](https://agnosticos.org) — the AI-native operating system.
