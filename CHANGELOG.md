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
  square wave, 200 ms, 48 kHz stereo S16_LE). Builds clean and is
  ready to actually emit sound after v0.2.0 #2 (below) — user
  runs it manually since it's audible.

### v0.2.0 progress (in-flight)

- **#2 — full `SNDRV_PCM_IOCTL_HW_PARAMS` (608-byte struct)**:
  done. `audio_set_params` now packs the real ioctl struct with
  ACCESS, FORMAT, SUBFORMAT mask constraints and CHANGES, RATE
  exact-value intervals; period / buffer / fifo left "any" so the
  kernel picks defaults. Verified on real hardware via
  `programs/probe.cyr` — full OPEN → SETUP → PREPARED state
  transition works against onboard analog out (`pcmC1D0p`).
- New constants in `src/alsa.cyr`: `AlsaHwParam` (mask + interval
  param indices), `AlsaSubformat`, `AlsaIntervalFlag`,
  `AlsaHwParamsLayout` (struct offsets pinned).
- Internal helpers: `_hwp_init_any`, `_hwp_mask_set_value`,
  `_hwp_interval_set_exact`, `_alsa_format_for_bits`.
- Test suite gains a `hw_params` group: 8 test functions /
  33 assertions covering struct layout offsets, mask / interval
  manipulation, and bit_depth → AlsaFormat mapping. Total suite
  82 → 115 assertions, all passing.
- `programs/probe.cyr` extended to call `vani_prepare` and verify
  `SETUP → PREPARED` transition on real hardware.

- **#3 — `SNDRV_PCM_IOCTL_HW_REFINE` capability query**: done.
  - `audio_query_caps(dev, hwp)` — fills hwp with all-bits-set,
    runs HW_REFINE, returns the kernel-narrowed view of what the
    device actually supports.
  - `audio_can_set_params(dev, rate, channels, bit_depth)` —
    cheap "is this combo supported" probe via HW_REFINE; no
    state transition.
  - HW_REFINE result readers: `_hwp_mask_has_bit`,
    `_hwp_interval_min`, `_hwp_interval_max`,
    `_hwp_interval_contains`.
  - `_alsa_bits_for_format` — inverse of `_alsa_format_for_bits`.
- **#4 — `vani_format_negotiate(d, preferred)`**: done. Returns
  `Result<VaniFormat>` with channels/rate clamped to device's
  supported range and format quality-walked
  S32→S24→S16→S8→U8 when preferred isn't available. Plus
  `vani_format_is_supported(d, fmt)` for boolean queries.
- `programs/caps.cyr` — capability probe that prints the device's
  supported channel range, rate range, period / buffer ranges,
  and format set, then exercises `vani_format_negotiate` against
  two preferred formats. PASS on real HW (card 1 device 0
  reports stereo-only, 44.1k–192k Hz, S16_LE+S32_LE; negotiation
  correctly clamped 8-channel preferred to 2-channel actual).
- Test suite gains an `hw_refine` group: 10 test fns / 31
  assertions covering mask/interval readers, clamp, and the
  negotiation picker (preferred-supported, fall-back paths,
  empty-mask, quality preference). Total 115 → 146 assertions.

### Architecture

- vani is now the single audio authority in stdlib (mirrors mabda
  for GPU, yukti for device discovery). Raw ALSA ioctls + typed
  errors + ring buffer + XRUN recovery + mixer all ship from one
  `dist/vani.cyr` bundle.
- `audio` removed from `[deps].stdlib` — vani owns that surface in
  `src/alsa.cyr`.
- yukti and sakshi are stdlib deps (no longer external git pins).
- `lib/` is now a build artifact (gitignored), populated by `cyrius deps`.
