# Vani — Claude Code Instructions

## Project Identity

**Vani** (Sanskrit: वाणी — voice, speech) — Audio device I/O for Cyrius. The voice of the system.

- **Type**: Shared library — audio hardware interface
- **License**: GPL-3.0-only
- **Language**: Cyrius (native)
- **Version**: SemVer, version file at `VERSION`
- **Status**: Scaffolded, pre-implementation
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md)

## Key Dependencies

- **yukti** — device discovery (vani does NOT scan hardware)
- **shravan** — audio codec decode/encode (vani handles raw PCM only)
- **agnosys** — syscall wrappers for ALSA ioctls
- **sakshi** — tracing

## Architecture

```
src/
  lib.cyr       — public API
  device.cyr    — ALSA device open/close/configure
  playback.cyr  — PCM write, ring buffer, underrun handling
  capture.cyr   — PCM read, ring buffer, overrun handling
  format.cyr    — sample format negotiation
  buffer.cyr    — ring buffer, latency control
  mixer.cyr     — hardware volume/mute via ALSA mixer ioctls
```

## Key Constraints

- **Direct ALSA ioctls only** — no PulseAudio, no PipeWire, no middleware
- **yukti provides device handles** — vani never scans /dev/ or /proc/ itself
- **PCM only** — raw samples in, raw samples out. Codec work is shravan's job.
- **Zero external deps** — pure Cyrius + syscalls
- **Latency-aware** — configurable buffer sizes for pro audio vs casual playback

## Development Process

1. **P(-1)** — vidya entry for ALSA ioctl patterns, PCM device model
2. Implement module by module
3. Test on real hardware (onboard audio first, then USB, then HDMI)
4. Benchmark: latency, throughput, underrun rate
5. CHANGELOG, roadmap

## DO NOT

- **Do not commit or push** — user handles git
- **NEVER use `gh` CLI**
- Do not implement device scanning — yukti handles that
- Do not implement codecs — shravan handles that
- Do not depend on PulseAudio or PipeWire
- Do not use floating point for sample processing — integer PCM
