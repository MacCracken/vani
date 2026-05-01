# Vani — Live State Snapshot

> **Refreshed every release.** This file holds volatile state — current
> version, test/bench counts, dist bundle size, real-HW verification
> hosts, in-flight items, recent shipped releases, downstream
> consumers. Durable rules live in [`CLAUDE.md`](../../CLAUDE.md).
> Historical narrative lives in [`CHANGELOG.md`](../../CHANGELOG.md).

## Release

| Field | Value |
|-------|-------|
| Current version | `0.3.0` |
| Released | 2026-04-30 |
| Cyrius toolchain pin | `5.7.48` |
| Yukti pin (`[deps.yukti]`) | tag `2.2.1` (git override until cyrius re-bundles ≥ 2.2.1) |
| Latest P(-1) audit | [`docs/audit/2026-04-30-v0.3.0-audit.md`](../audit/2026-04-30-v0.3.0-audit.md) |

## Test / Bench Counts

| Metric | Value |
|--------|-------|
| CPU test assertions | 258 (groups: error, format, buffer, device, yukti, audit-2026-04-30, hw_params, hw_refine, mixer, v0.4.0 state + sw_params) |
| CPU benchmarks | 13 (format / ring / hwp / negotiate paths) |
| Real-HW programs | 8 (`smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`) |
| Bench history baseline | commit `e031c0d` (2026-04-30); current at `189bbab` |

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
| aarch64 cross-build unblock | v0.4.x | `src/alsa.cyr` raw `SYS_OPEN` → stdlib `sys_*` wrappers; CI workflow comment points here |
| XRUN-rate stress benchmark | v0.4.0 | Sustained-load harness with `stress-ng` CPU contention |
| USB audio interface integration | v0.5.x | HW-gated (need a Behringer UCA222 / Focusrite Scarlett class) |
| HDMI audio integration | v0.5.x | `pcmC0D{3,7,8,9}p` on the dev box's existing card 0 |
| Sub-10ms low-latency on USB | v0.5.x | onboard HDA rejects sub-10ms periods |

## Downstream Consumers

> When this list reaches 2+ live consumers, the v1.0.0 freeze
> criteria #2 / #3 are met.

| Project | Status | Notes |
|---------|--------|-------|
| cyrius-doom | not yet integrated | tracked as v1.0.0 #2 |
| jalwa | not yet integrated | tracked as v1.0.0 #3 candidate |
| dhvani | not yet integrated | tracked as v1.0.0 #3 candidate |
| agnoshi | not yet integrated | tracked as v1.0.0 #3 candidate |

## Shipped Releases

| Tag | Date | Highlights |
|-----|------|------------|
| `0.3.0` | 2026-04-30 | First public release. Foundation through yukti integration; rolls up the v0.1.0 / v0.2.0 / v0.3.0 development milestones. |

## Bootstrap Chain

Vani depends on:

```
cyrius (5.7.48)
  ├─ stdlib (16 modules: syscalls / string / alloc / str / fmt /
  │        vec / io / fs / args / hashmap / tagged / fnptr /
  │        freelist / process / patra / sakshi)
  └─ [deps.yukti] (git tag 2.2.1) — pinned ahead of cyrius's bundled
                                     yukti 2.1.1 until rebundle.
```

No external (non-cyrius, non-AGNOS) git deps.
