# Vani — Live State Snapshot

> **Refreshed every release.** This file holds volatile state — current
> version, test/bench counts, dist bundle size, real-HW verification
> hosts, in-flight items, recent shipped releases, downstream
> consumers. Durable rules live in [`CLAUDE.md`](../../CLAUDE.md).
> Historical narrative lives in [`CHANGELOG.md`](../../CHANGELOG.md).

## Release

| Field | Value |
|-------|-------|
| Current version | `0.9.7` (pre-1.0 release candidate, audio-core profile + AGNOS backend) |
| Released | 2026-07-04 |
| Cyrius toolchain pin | `6.3.5` |
| Yukti pin (`[deps.yukti]`) | tag `2.2.7` (git override until cyrius re-bundles ≥ 2.2.7) |
| Patra pin (`[deps.patra]`) | tag `1.12.7` (git override for aarch64 portability; until cyrius re-bundles ≥ 1.12.7) |
| Distribution profiles | full (`dist/vani.cyr`, 76 KB / 106 symbols) and core (`dist/vani-core.cyr`, 29 KB / 22 symbols) |
| Latest P(-1) audit | [`docs/audit/2026-05-01-v0.9.1-audit.md`](../audit/2026-05-01-v0.9.1-audit.md) |
| Architectures supported | x86_64-linux, aarch64-linux (since 0.9.0) |

## Test / Bench Counts

| Metric | Value |
|--------|-------|
| CPU test assertions | 258 (groups: error, format, buffer, device, yukti, audit-2026-04-30, hw_params, hw_refine, mixer, v0.4.0 state + sw_params) |
| CPU benchmarks | 13 (format / ring / hwp / negotiate paths) |
| Real-HW programs | 8 (`smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`) |
| Bench history baseline | commit `e031c0d` (2026-04-30 v0.1.0); latest row `59dd681` (2026-05-21, v0.9.4). 0.9.5 / 0.9.6 not appended (quiet pin bumps; plus the cyrius 6.3.5 bench-CSV µs bug below). |

## Build Artifacts

| Artifact | Size | Notes |
|----------|------|-------|
| `dist/vani.cyr` (full profile) | 76,124 B / 2101 lines (v0.9.1) | Full consumer-facing bundle: 106 public symbols across alsa/error/format/buffer/device/playback/capture/mixer |
| `dist/vani-core.cyr` (core profile) | 29,015 B / 800 lines (v0.9.1) | Playback-only single-module bundle: 22 `audio_*` symbols from `src/alsa.cyr` only. **62% smaller** than full. |
| `build/vani_smoke` | ~438 KB (DCE off) | x86_64 ELF link-check binary |
| `build/vani_smoke-aarch64` | (built per cut) | aarch64 ELF link-check binary (since 0.9.0) |
| `build/vani_smoke` (DCE) | 489,520 B (0.9.6) | x86_64; grew from yukti 2.2.7 device_db surface + the new `chrono` stdlib module |
| `dist/vani.deps`, `dist/vani-core.deps` | 14 stdlib leaves each | cyrius 6.3.5 distlib sidecars (auto-generated, consumed by consumers' `cyrius deps`); committed alongside the bundles, matching patra's convention |

## Real-HW Verification

| Host | Cards / Devices | Status |
|------|-----------------|--------|
| Dev box (HDA Generic + HDMI + ACP) | 8 PCM endpoints across cards 0/1/2 | All 8 programs PASS as of 0.3.0 |
| First playback target | card 1 device 0 / `pci:0000:04:00.6:dev0:p` (ALC897 Analog) | `probe`, `devices`, `tone` round-trip clean |
| **Consumer audible** (cyrius-doom 0.30.5) | card 1 device 0 (ALC897), auto-selected by doom's capture-sibling scan | **First audible real-HW consumer** (2026-06-29): DOOM SFX play end-to-end through vani at **S16_LE / stereo / 44100** (`audio_set_params_full` + `sw_params`); not just degrade-clean — actual sound out |

| Hardware class | v0.3.0 status | Tracked in |
|----------------|---------------|------------|
| Onboard analog (HDA Generic, ALC897) | Verified | — |
| HDMI audio (HDA Generic) | Enumerated by `vani_devices`, not yet round-tripped | roadmap v0.5.x |
| USB audio interface | Not yet tested | roadmap v0.5.x |

## In-flight

| Item | Target | Notes |
|------|--------|-------|
| XRUN-rate stress benchmark | optional pre-1.0 | Not blocking 1.0; reproducing CPU contention reliably needs harness setup beyond a release gate. |
| Portable `_clock_monotonic()` for throughput / latency_test | optional pre-1.0 | `programs/throughput.cyr` and `programs/latency_test.cyr` still use raw `syscall(228)` (clock_gettime). x86_64-only by design — fixes when an aarch64 dev host with audio HW exists. |
| USB audio interface integration | v0.5.x | HW-gated (need a Behringer UCA222 / Focusrite Scarlett class). |
| cyrius 6.3.5 bench-CSV µs 10× bug | toolchain (watch) | `cyrius bench` CSV emitter inflates µs-formatted values 10× (`ring_200ms_playback` → `823525` vs. the true ~82–86k ns; human-readable output correct). Do **not** append raw CSV µs rows to `bench-history.csv` until a cyrius fix lands. |
| HDMI audio integration | v0.5.x | `pcmC0D{3,7,8,9}p` on the dev box's existing card 0. |
| Sub-10ms low-latency on USB | v0.5.x | onboard HDA rejects sub-10ms periods. |

## Downstream Consumers

> v1.0.0 freeze criteria #2 / #3 are **met**: **3 live consumers**
> (doom, polyomino, bb), past the "2+ live consumers" bar; the core
> profile is now **real-HW-audible-verified** (doom 0.30.5, 2026-06-29 —
> first consumer confirmed making sound on hardware). **Caveat:** all
> three exercise only the `audio_*` **core** profile — the full `vani_*`
> surface (ring / capture / mixer / XRUN / `vani_open_yukti`) has zero
> live-consumer validation (see v1.0.0 #5, split-freeze note).

| Project | Status | Notes |
|---------|--------|-------|
| cyrius-doom | **live + audibly verified on real HW** — declared `[deps.vani]`, core profile | Released **0.30.5** (committed + tagged `0.30.5`, HEAD `95f8e76`). `[deps.vani]` git override at tag `0.9.5` (one patch behind current 0.9.6). **First consumer confirmed audible on real hardware** (2026-06-29): DOOM SFX (DSPISTOL/DSDOROPN/…) play end-to-end through `audio_write` in the 35 Hz `audio_tick` loop, at **S16_LE / stereo / 44100** (converted from DOOM's native 8-bit-mono 11025). Deepest exerciser of the three: `audio_open_best` multi-card scan auto-selects the analog codec (card 1 dev 0 here) by probing for a capture sibling (`audio_open_capture`), then configures via `audio_set_params_full` (period/buffer) + `audio_set_sw_params` (start threshold). **9** `audio_*` symbols — incl. the first consumer touch of `audio_open_capture` (probe-only, no `audio_read`). |
| cyrius-polyomino | **live** — vendored vani-core, core profile | Released **0.5.1** (committed + tagged). Vendors `vendor/vani-core.cyr` (vani 0.9.6 core) to avoid the patra/yukti transitive bloat. Piece-lock / line-clear / level-up / top-out SFX → `audio_write` in the ~60 fps `run_interactive` loop (default `argc<2` path). 6 `audio_*` symbols. Defaults to card 1 dev 0 (`AudioDev` constants). |
| cyrius-bb | **live** — vendored vani-core, core profile | Released **0.8.0** (committed + tagged). Replaced its legacy OSS `/dev/dsp` sink with vendored `vendor/vani-core.cyr` (vani 0.9.6 core). Brick/wall/paddle + lost/over/fanfare SFX → `audio_write_bytes` in `play_game`'s frame loop (default `run_interactive`). 6 `audio_*` symbols. |
| jalwa / dhvani / agnoshi | not yet integrated | The original v1.0.0 #3 candidates, still gated (jalwa/dhvani Rust→Cyrius port; agnoshi no audio path). Superseded as the #3 trigger by the three game consumers above — they were illustrative of the expected ecosystem, not a hard allowlist. |

## Shipped Releases

| Tag | Date | Highlights |
|-----|------|------------|
| `0.9.6` | 2026-06-29 | `cyrius` pin `6.2.1` → `6.3.5`; `[deps.yukti]` `2.2.4` → `2.2.7` (clears the `ERR_TIMEOUT` duplicate-symbol collision); `[deps.patra]` `1.9.5` → `1.12.7`; added stdlib `chrono` (yukti 2.2.6+ calls `clock_epoch_secs`, hard-required under cyrius 6.3.2's undefined-fn-is-error). 258/258, 0 warnings. |
| `0.9.5` | 2026-06-12 | `cyrius` pin `6.0.1` → `6.2.1` (ecosystem stdlib pin sweep; no source changes). |
| `0.9.4` | 2026-05-21 | `cyrius` toolchain pin bumped 5.11.4 → 6.0.1. `[deps.yukti]` bumped 2.2.2 → 2.2.4, `[deps.patra]` bumped 1.9.3 → 1.9.5. |
| `0.9.3` | 2026-05-11 | Stdlib annotation pass — every public fn in `src/*.cyr` carries a `: i64` return-type annotation (parse-only). `cyrius` pin bumped 5.8.64 → 5.11.4 for the v5.10.x type-system arc. |
| `0.9.1` | 2026-05-01 | `core` distribution profile added. `cyrius distlib core` → `dist/vani-core.cyr` (29 KB, 22 symbols, 62% smaller than full). Drives the cyrius-doom audio-core consumer story without touching the full bundle or the public API. |
| `0.9.0` | 2026-04-30 | Pre-1.0 release candidate. aarch64 cross-build unblocked (73-site syscall migration); CI/release ships `vani-0.9.0-smoke-aarch64-linux`; `[deps.patra]` git-pinned at 1.9.2; API surface baseline captured at `docs/api-surface.snapshot`. |
| `0.3.0` | 2026-04-30 | First public release. Foundation through yukti integration; rolls up the v0.1.0 / v0.2.0 / v0.3.0 development milestones. |

## Bootstrap Chain

Vani depends on:

```
cyrius (6.3.5)
  ├─ stdlib (16 modules: syscalls / string / alloc / str / fmt /
  │        vec / io / fs / args / hashmap / tagged / fnptr /
  │        freelist / process / chrono / sakshi)
  ├─ [deps.yukti] (git tag 2.2.7) — pinned ahead of cyrius's bundled
  │                                  yukti until rebundle.
  └─ [deps.patra] (git tag 1.12.7) — pinned ahead of cyrius's bundled
                                     patra for aarch64
                                     portability; until rebundle.
```

No external (non-cyrius, non-AGNOS) git deps.
