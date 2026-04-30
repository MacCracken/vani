# Vani Development Roadmap

> **v0.1.0** — Restarted scaffold (2026-04-30). Audio device I/O for Cyrius.

## v0.1.0 — Foundation (current)

| # | Item | Status |
|---|------|--------|
| 1 | Manifest on `cyrius.cyml` (5.7.39 pin) | Done |
| 2 | `src/lib.cyr` include chain | Done |
| 3 | Absorb `cyrius/lib/audio.cyr` → `src/alsa.cyr` | Done |
| 4 | `VaniErr` + Result helpers | Done |
| 5 | `VaniFormat` + frame/byte math | Done |
| 6 | Pow-of-2 ring buffer | Done |
| 7 | `VaniDevice` handle wrapping `alsa.cyr` | Done |
| 8 | `vani_play` + XRUN re-prepare retry | Done |
| 9 | `vani_record` + XRUN re-prepare retry | Done |
| 10 | Smoke link-check program | Done |
| 11 | CPU-only test suite | Done |
| 12 | Cyrius 5.8.0 fold-in plan documented | Done |
| 13 | Real-hardware integration test (onboard audio) | Not started |
| 14 | `dist/vani.cyr` via `cyrius distlib` | Done |

## v0.2.0 — Hardware coverage + benchmarks

| # | Item | Status |
|---|------|--------|
| 1 | Full `SNDRV_PCM_IOCTL_HW_PARAMS` struct (608 B) — proper negotiation | Not started |
| 2 | `SNDRV_PCM_IOCTL_HW_REFINE` for capability query | Not started |
| 3 | Onboard audio integration test (real PCM round-trip) | Not started |
| 4 | USB audio integration test | Not started |
| 5 | HDMI audio integration test | Not started |
| 6 | Latency / throughput / underrun-rate benchmarks (CSV history) | Not started |
| 7 | `cyrius bench tests/bcyr/vani.bcyr` for ring + format math | Not started |

## v0.3.0 — Mixer + yukti adapter

| # | Item | Status |
|---|------|--------|
| 1 | `snd_ctl_elem_id` + `snd_ctl_elem_value` struct packing | Not started |
| 2 | `vani_mixer_set_volume` real implementation | Not started |
| 3 | `vani_mixer_set_mute` real implementation | Not started |
| 4 | `vani_mixer_list_elements` for enumeration | Not started |
| 5 | `vani_open_yukti` real adapter (typed yukti descriptor → open) | Not started |
| 6 | Multi-device routing helpers | Not started |

## v0.4.0 — Latency + correctness

| # | Item | Status |
|---|------|--------|
| 1 | Configurable buffer size on configure (period_size, periods) | Not started |
| 2 | `SNDRV_PCM_IOCTL_SW_PARAMS` (start_threshold, stop_threshold) | Not started |
| 3 | Suspend/resume support | Not started |
| 4 | `audio_get_state` → typed `VaniState` enum | Not started |

## Cyrius 5.8.0 fold-in (cross-cuts vani v0.1.0–v0.2.0)

See `cyrius-stdlib-fold-in.md` for the concrete steps. Summary:
add `[deps.vani]` to `cyrius/cyrius.cyml`, delete
`cyrius/lib/audio.cyr`, downstream consumers swap
`include "lib/audio.cyr"` → `include "lib/vani.cyr"`. Vani's
`audio_*` API is byte-stable so migration is mechanical.

## v1.0.0 — Stable

| # | Item | Status |
|---|------|--------|
| 1 | `dist/vani.cyr` shipped as Cyrius stdlib bundle (5.8.0) | Not started |
| 2 | Tested on 3+ hardware targets (onboard, USB, HDMI) | Not started |
| 3 | Benchmark Rust-parity reference (if a Rust v1 ever exists) | Not started |
| 4 | DOOM audio upgrade (PC speaker → real audio) — first consumer | Not started |
| 5 | Public API frozen; SemVer guarantees from here | Not started |
