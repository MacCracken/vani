# 0002 — Freeze the full `vani_*` surface at 1.0.0

> **Status**: Accepted
> **Date**: 2026-07-06
> **Authors**: Robert MacCracken

## Context

The v1.0.0 freeze had to choose *what* to place under SemVer. Two
distribution profiles exist: the 22-symbol `audio_*` **core** shim
(`dist/vani-core.cyr`) and the full 106-symbol `vani_*` surface
(`dist/vani.cyr` — ring / capture / playback / device / format / mixer /
`vani_open_yukti`).

Through 0.9.x the core shim was production-proven across three live
consumers (cyrius-doom, -polyomino, -bb — the last audible on real
hardware), but the **full `vani_*` surface had zero live-consumer
validation**. On that basis the roadmap's v1.0 criterion #5 recommended a
**split-freeze**: stabilize the core profile at 1.0.0 and hold the full
surface at an experimental SemVer tier until a consumer exercised it.

Two things changed at the 1.0.0 cut:

1. **dhvani 2.1.2** landed as a live consumer of the full surface — its
   `src/playback.cyr` bridges dhvani's f64 `AudioBuffer` to vani's PCM,
   exercising `vani_open_playback` / `_open_capture`, `vani_ring_new` /
   `_write` / `_read`, `vani_play` / `_play_from_ring`, `vani_record` /
   `_record_to_ring`, `vani_configure`, `vani_format_new`, `vani_alsa_for`,
   `vani_start`, `vani_close`.
2. **mishran 0.2.0** wired the core sink as a fourth consumer, verified on
   real hardware (2026-07-06), and the 2026-07-06 closeout audit swept the
   surface clean (one dormant PAUSE ioctl number fixed; no HIGH+ findings).

That removes the premise the split-freeze rested on for
ring/capture/playback/device/format. Two corners remain
consumer-unvalidated — `vani_open_yukti` (the yukti adapter) and
`src/mixer.cyr` (hardware volume/mute controls) — but both are
internally test-covered (part of the 259-assertion suite).

## Decision

**Freeze the entire 106-symbol `vani_*` public surface under SemVer at
1.0.0.** The frozen baseline is `docs/api-surface.snapshot`, gated in CI.
Removing or changing the signature of any listed symbol is a breaking
change requiring a **2.0.0** major bump.

## Consequences

- Consumers get one coherent SemVer contract over the whole library — no
  two-tier "some symbols stable, some experimental" story to track.
- The two consumer-unvalidated corners (`vani_open_yukti`, `src/mixer.cyr`)
  are frozen on the strength of their internal test coverage alone. If a
  real consumer later exposes a design flaw in either that needs a breaking
  fix, that fix costs a major bump. Accepted, and recorded here so the cost
  is not a surprise.
- USB / HDMI hardware coverage (roadmap criterion #1) is explicitly **not**
  a freeze blocker — the same frozen code path drives them; only on-silicon
  verification is missing, and that does not touch the API. Deferred to
  post-1.0 as HW-gated work.
- **Not reversible** — a 1.0.0 freeze is a public commitment. There is no
  trigger that un-freezes; corrections flow through normal SemVer (patch for
  fixes, minor for additions, major for breaks).

## Alternatives considered

- **Split-freeze (core stable, full experimental)** — the earlier roadmap
  recommendation. Lost because dhvani now validates the full surface live,
  so holding it "experimental" understates its maturity and fragments the
  SemVer contract for no benefit.
- **Hold 1.0.0 until USB + HDMI hardware is verified** (criterion #1 in
  full). Lost because the gap is hardware access, not code; it could block
  1.0 indefinitely while adding no API confidence.

## References

- `docs/development/roadmap.md` — v1.0.0 criteria closeout (SHIPPED 2026-07-06).
- `docs/audit/2026-07-06-v1.0.0-audit.md` — closeout security/CVE sweep.
- `docs/api-surface.snapshot` — the frozen 106-symbol v1.0 baseline.
- CHANGELOG `[1.0.0]` — Added (dhvani / mishran), Breaking (none for consumers).
