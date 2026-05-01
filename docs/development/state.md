# Vani — Live State Snapshot

> **Refreshed every release.** This file holds volatile state — current
> version, test/bench counts, dist bundle size, real-HW verification
> hosts, in-flight items, recent shipped releases, downstream
> consumers. Durable rules live in [`CLAUDE.md`](../../CLAUDE.md).
> Historical narrative lives in [`CHANGELOG.md`](../../CHANGELOG.md).

## Release

| Field | Value |
|-------|-------|
| Current version | `0.9.0` (pre-1.0 release candidate) |
| Released | 2026-04-30 |
| Cyrius toolchain pin | `5.7.48` |
| Yukti pin (`[deps.yukti]`) | tag `2.2.1` (git override until cyrius re-bundles ≥ 2.2.1) |
| Patra pin (`[deps.patra]`) | tag `1.9.2` (git override for aarch64 portability; until cyrius re-bundles ≥ 1.9.2) |
| Latest P(-1) audit | [`docs/audit/2026-04-30-v0.9.0-audit.md`](../audit/2026-04-30-v0.9.0-audit.md) |
| Architectures supported | x86_64-linux, aarch64-linux (since 0.9.0) |

## Test / Bench Counts

| Metric | Value |
|--------|-------|
| CPU test assertions | 258 (groups: error, format, buffer, device, yukti, audit-2026-04-30, hw_params, hw_refine, mixer, v0.4.0 state + sw_params) |
| CPU benchmarks | 13 (format / ring / hwp / negotiate paths) |
| Real-HW programs | 8 (`smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`) |
| Bench history baseline | commit `e031c0d` (2026-04-30 v0.1.0); current at v0.9.0 commit (per latest `bench-history.csv` row) |

## Build Artifacts

| Artifact | Size | Notes |
|----------|------|-------|
| `dist/vani.cyr` | 2072 lines (v0.3.0) | Consumer-facing single-include bundle |
| `build/vani_smoke` | 438168 bytes (DCE off) | x86_64 ELF link-check binary |
| `build/vani_smoke` (DCE) | bumped per release | Set in CI release workflow |

## Real-HW Verification

| Host | Cards / Devices | Status |
|------|-----------------|--------|
| Dev box (HDA Generic + HDMI + ACP) | 8 PCM endpoints across cards 0/1/2 | All 8 programs PASS as of 0.3.0 |
| First playback target | card 1 device 0 / `pci:0000:04:00.6:dev0:p` (ALC897 Analog) | `probe`, `devices`, `tone` round-trip clean |

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
| HDMI audio integration | v0.5.x | `pcmC0D{3,7,8,9}p` on the dev box's existing card 0. |
| Sub-10ms low-latency on USB | v0.5.x | onboard HDA rejects sub-10ms periods. |

## Downstream Consumers

> When this list reaches 2+ live consumers, the v1.0.0 freeze
> criteria #2 / #3 are met.

| Project | Status | Notes |
|---------|--------|-------|
| cyrius-doom | **integrated** (against vani 0.3.0) — pending the doom-side commit/tag | v1.0.0 #2 satisfied. Integration shape: `[deps.vani]` git override + drop `audio` from stdlib. Zero changes in doom's `src/audio.cyr` (byte-stable `audio_*` API). End-to-end smoke against shareware DOOM1.WAD: WAD loaded, map E1M1 loaded, audio degrade-path ("no device" — card 0 has no PCM device 0 on the dev box) clean, render pipeline continues, exit 0. |
| jalwa | not yet integrated — still Rust as of 2026-04-29 | v1.0.0 #3 candidate; gated on Rust → Cyrius port. |
| dhvani | not yet integrated — still Rust as of 2026-04-02 | v1.0.0 #3 candidate; gated on Rust → Cyrius port. |
| agnoshi | not yet integrated — Cyrius (4.5.0 pin), no audio path yet | v1.0.0 #3 candidate; gated on agnoshi gaining audio + a toolchain refresh. |

## Shipped Releases

| Tag | Date | Highlights |
|-----|------|------------|
| `0.9.0` | 2026-04-30 | Pre-1.0 release candidate. aarch64 cross-build unblocked (73-site syscall migration); CI/release ships `vani-0.9.0-smoke-aarch64-linux`; `[deps.patra]` git-pinned at 1.9.2; API surface baseline captured at `docs/api-surface.snapshot`. |
| `0.3.0` | 2026-04-30 | First public release. Foundation through yukti integration; rolls up the v0.1.0 / v0.2.0 / v0.3.0 development milestones. |

## Bootstrap Chain

Vani depends on:

```
cyrius (5.7.48)
  ├─ stdlib (15 modules: syscalls / string / alloc / str / fmt /
  │        vec / io / fs / args / hashmap / tagged / fnptr /
  │        freelist / process / sakshi)
  ├─ [deps.yukti] (git tag 2.2.1) — pinned ahead of cyrius's bundled
  │                                  yukti 2.1.1 until rebundle.
  └─ [deps.patra] (git tag 1.9.2) — pinned ahead of cyrius's bundled
                                     patra 1.9.0 for aarch64
                                     portability; until rebundle.
```

No external (non-cyrius, non-AGNOS) git deps.
