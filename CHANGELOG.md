# Changelog

All notable changes to Vani will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — Unreleased

### Added

- Project restarted 2026-04-30 after a partial-push lost the prior tree.
- Manifest moved from legacy `cyrius.toml` to `cyrius.cyml` (5.7.39 pin).
- Flat `src/*.cyr` module layout matching mabda / yukti.
- `src/alsa.cyr` — raw ALSA PCM ioctls (`audio_*` API). Lifted from
  `cyrius/lib/audio.cyr` so vani owns the full audio stack end-to-end.
  Targeting cyrius 5.8.0 to retire the legacy stdlib path — see
  `docs/development/cyrius-stdlib-fold-in.md`.
- `src/error.cyr` — `VaniErr` codes + Result helpers + sakshi observability gate.
- `src/format.cyr` — `VaniFormat` struct, common rates, frame / byte math, AlsaFormat picker.
- `src/buffer.cyr` — pow-of-two byte ring buffer with mask-wrap, occupancy queries.
- `src/device.cyr` — `VaniDevice` handle wrapping `alsa.cyr`; lifecycle + xrun counter.
- `src/playback.cyr` — `vani_play` + `vani_play_from_ring` with XRUN re-prepare retry.
- `src/capture.cyr` — `vani_record` + `vani_record_to_ring` with XRUN re-prepare retry.
- `src/mixer.cyr` — `/dev/snd/controlC{N}` open / close + ioctl number table; volume/mute API stubbed pending v0.3.0 struct packing.
- `programs/smoke.cyr` — link-check for the full include chain.
- `tests/tcyr/vani.tcyr` — CPU-only suite covering error codes, format math, ring buffer, direction constants.
- `docs/development/cyrius-stdlib-fold-in.md` — concrete plan for the
  cyrius 5.8.0 fold-in (add `[deps.vani]` to cyrius/cyrius.cyml,
  delete cyrius/lib/audio.cyr, downstream consumers swap
  `include "lib/audio.cyr"` → `include "lib/vani.cyr"`).

### Fixed

- `audio_write` / `audio_read` declared `var xferi[2]` (2 bytes on
  stack) but wrote 16 bytes through it — bug carried over from
  upstream `cyrius/lib/audio.cyr`. Corrected to `var xferi[16]`
  during the absorb.
- **First P(-1) scaffold-hardening sweep** (audit
  `docs/audit/2026-04-30-audit.md`):
  - HIGH-1 — added missing transitive stdlib deps (`patra`,
    `freelist`, `fs`, `process`) that yukti requires. Build was
    warning "will crash at runtime" on `patra_*` symbols; only
    safe today because `vani_open_yukti` is a stub.
  - MED-1 — `_audio_devpath` (`src/alsa.cyr`) and
    `_vani_ctl_path` (`src/mixer.cyr`) used `card % 10` to
    encode the card digit, silently routing card 10 to card 0.
    Replaced with proper 1-2 digit decimal encoding; cards 100+
    return null so the open() that follows fails cleanly.
  - LOW-1 — bounded `vani_ring_new` and `_next_pow2` at 1 GiB
    (`VANI_RING_MAX_BYTES`). Prevents pathological capacity
    requests from overflowing the doubling loop.
  - DEFENSE-IN-DEPTH (CVE-2025-40269 class) — `audio_write` /
    `audio_read` now reject frame counts above `AUDIO_FRAMES_MAX`
    (2^28 = 256 M frames). Mitigates kernel transfer paths that
    historically did narrower-int arithmetic on
    `frames * bytes_per_frame`.

### Tests

- `tests/tcyr/vani.tcyr` grows an `audit-2026-04-30` group: 8 test
  functions / 20 assertions. Suite total 62 → 82 assertions, all
  passing.
- `programs/probe.cyr` — first real-hardware integration test.
  Walks vani's syscall path end-to-end (open / state-query /
  configure / state-query / close) against `/dev/snd/pcmC{N}D{M}p`
  without producing audio. Verified PASS on the dev box's
  onboard analog out (`pcmC1D0p`).
- `programs/play_tone.cyr` — v0.2.0 acceptance fixture (440 Hz
  square wave, 200 ms, 48 kHz stereo S16_LE). Kept in the tree;
  builds today; will fail at prepare until v0.2.0 lands the full
  `SNDRV_PCM_IOCTL_HW_PARAMS` 608-byte struct packing.

### Architecture

- vani is now the single audio authority in stdlib (mirrors mabda
  for GPU, yukti for device discovery). Raw ALSA ioctls + typed
  errors + ring buffer + XRUN recovery + mixer all ship from one
  `dist/vani.cyr` bundle.
- `audio` removed from `[deps].stdlib` — vani owns that surface in
  `src/alsa.cyr`.
- yukti and sakshi are stdlib deps (no longer external git pins).
- `lib/` is now a build artifact (gitignored), populated by `cyrius deps`.
