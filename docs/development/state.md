# Vani — Live State Snapshot

> **Refreshed every release.** This file holds volatile state — current
> version, test/bench counts, dist bundle size, real-HW verification
> hosts, in-flight items, recent shipped releases, downstream
> consumers. Durable rules live in [`CLAUDE.md`](../../CLAUDE.md).
> Historical narrative lives in [`CHANGELOG.md`](../../CHANGELOG.md).

## Release

| Field | Value |
|-------|-------|
| Current version | `1.0.0` (stable — full `vani_*` API frozen under SemVer) |
| Released | 2026-07-06 |
| Cyrius toolchain pin | `6.4.10` |
| Dependency model | **all-stdlib** — no git overrides, no `cyrius.lock`. `yukti` + `patra` (and patra's transitive `atomic` / `sync` / `thread_local`) are stdlib modules as of the 0.9.9 all-stdlib cut (cyrius ≥ 6.4.3 bundles vani/yukti/patra) |
| Distribution profiles | full (`dist/vani.cyr`, 80,630 B / 106 symbols) and core (`dist/vani-core.cyr`, 33,114 B / 22 symbols) |
| API surface baseline | `docs/api-surface.snapshot` (106 public fns) — the **frozen v1.0 baseline**; `docs/api-surface.core.snapshot` (22) |
| Latest audit | [`docs/audit/2026-07-06-v1.0.0-audit.md`](../audit/2026-07-06-v1.0.0-audit.md) |
| Architectures supported | x86_64-linux, aarch64-linux (since 0.9.0) |

## Test / Bench Counts

| Metric | Value |
|--------|-------|
| CPU test assertions | 258 (groups: error, format, buffer, device, yukti, audit-2026-04-30, hw_params, hw_refine, mixer, v0.4.0 state + sw_params) |
| CPU benchmarks | 13 (format / ring / hwp / negotiate paths) |
| Real-HW programs | 8 (`smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`) |
| Bench history baseline | commit `e031c0d` (2026-04-30 v0.1.0); latest row `59dd681` (2026-05-21, v0.9.4). The cyrius bench-CSV µs 10× bug is **fixed in 6.4.10** (`ring_200ms_playback` CSV now `80916` ≈ 80.9 µs, matching human-readable) — CSV rows are trustworthy again and may be appended. |

## Build Artifacts

| Artifact | Size | Notes |
|----------|------|-------|
| `dist/vani.cyr` (full profile) | 80,630 B / 2181 lines (v1.0.0) | Full consumer-facing bundle: 106 public symbols across alsa/error/format/buffer/device/playback/capture/mixer. Grew from v0.9.1's 76 KB with the 0.9.7 agnos `#ifdef` backend branches. |
| `dist/vani-core.cyr` (core profile) | 33,114 B / 900 lines (v1.0.0) | Playback-only single-module bundle: 22 `audio_*` symbols from `src/alsa.cyr` only (incl. the agnos backend). ~59% smaller than full. |
| `build/vani_smoke` (DCE) | ~308,857 B NOPed at link | x86_64 ELF link-check binary |
| `build/vani_smoke-aarch64` | (built per cut) | aarch64 ELF link-check binary (since 0.9.0) |
| `dist/vani.deps`, `dist/vani-core.deps` | 15 stdlib leaves each | cyrius distlib sidecars (auto-generated, consumed by consumers' `cyrius deps`); committed alongside the bundles. |

## Real-HW Verification

| Host | Cards / Devices | Status |
|------|-----------------|--------|
| Dev box (HDA Generic + HDMI + ACP) | 8 PCM endpoints across cards 0/1/2 | All 8 programs PASS as of 0.3.0 (run inside a desktop audio session — the `/dev/snd/pcm*` nodes are `root:audio`, so a non-session shell without `audio`-group/logind-ACL access sees open-EACCES and the programs degrade clean) |
| First playback target | card 1 device 0 / `pci:0000:04:00.6:dev0:p` (ALC897 Analog) | `probe`, `devices`, `tone` round-trip clean |
| **Consumer audible** (cyrius-doom 0.30.5) | card 1 device 0 (ALC897) | **First audible real-HW consumer** (2026-06-29): DOOM SFX play end-to-end through vani at S16_LE / stereo / 44100 |
| **Consumer sink** (mishran 0.2.0) | card 1 device 0 | `pump_probe` **verified on real HW** (2026-07-06, remote session): router → vani sink open → pump → drain clean (silent — mixed silence through `audio_write` with `-EPIPE` recovery) |

| Hardware class | status | Tracked in |
|----------------|--------|------------|
| Onboard analog (HDA Generic, ALC897) | Verified + audible | — |
| HDMI audio (HDA Generic) | Enumerated by `vani_devices`, not yet round-tripped | roadmap post-1.0 (HW-gated) |
| USB audio interface | Not yet tested | roadmap post-1.0 (HW-gated) |

## In-flight

| Item | Target | Notes |
|------|--------|-------|
| USB + HDMI real-HW round-trip | post-1.0 (HW-gated) | The v1.0 freeze criterion #1 residual. Same frozen code path as onboard HDA; verification needs USB-class / HDMI hardware access. Does **not** touch the frozen API. |
| XRUN-rate stress benchmark | optional post-1.0 | Reproducing CPU contention reliably needs harness setup beyond a release gate. |
| Portable `_clock_monotonic()` for throughput / latency_test | optional post-1.0 | `programs/throughput.cyr` / `latency_test.cyr` still use raw `syscall(228)` (x86_64-only by design); fixes when an aarch64 dev host with audio HW exists. |

## Downstream Consumers

> v1.0.0 froze the **full `vani_*` surface** under SemVer. The full
> ring/capture/playback/device/format surface is now live-consumer
> validated by **dhvani** (the earlier "zero full-surface consumer"
> blocker is cleared). The two remaining consumer-unvalidated corners
> are `vani_open_yukti` (the yukti adapter) and `src/mixer.cyr` (the
> hardware volume/mute control surface) — both internally test-covered
> (258 assertions) but not yet exercised by a live consumer.

| Project | Status | Notes |
|---------|--------|-------|
| **dhvani** | **live — FULL `vani_*` surface** | Released **2.1.2**. `src/playback.cyr` bridges dhvani's f64 AudioBuffer ↔ vani's interleaved S16/S24/S32 PCM, exercising the full device path: `vani_open_playback` / `vani_open_capture`, `vani_ring_new` / `_write` / `_read`, `vani_play` / `vani_play_from_ring`, `vani_record` / `_record_to_ring`, `vani_configure`, `vani_format_new`, `vani_alsa_for`, `vani_start`, `vani_close`. References vani through functions only, so it DCE-prunes for vani-free consumers. **This is the consumer that unblocks the full-surface 1.0 freeze.** |
| cyrius-doom | **live + audibly verified on real HW** — core profile | Released **0.30.5** (tagged). DOOM SFX route through `audio_write` in the 35 Hz `audio_tick` loop; audible at S16/stereo/44100 (2026-06-29). Deepest core exerciser: `audio_set_params_full` (period/buffer) + `audio_set_sw_params` + an `audio_open_capture` codec probe. Vendors `vendor/vani-core.cyr`. |
| cyrius-polyomino | **live** — core profile | Released **0.5.1** (tagged). Vendors `vendor/vani-core.cyr`. Piece-lock / line-clear / level-up / top-out SFX → `audio_write`. 6 `audio_*` symbols. |
| cyrius-bb | **live** — core profile | Released **0.8.0** (tagged). Vendors `vendor/vani-core.cyr`. Brick/wall/paddle + lost/over/fanfare SFX → `audio_write_bytes`. 6 `audio_*` symbols. |
| **mishran** | **live — core sink (real-HW verified)** | **0.2.0** (unreleased, pre-git). The AGNOS software audio mixer / routing daemon (मिश्रण — "mixing"): fans many per-app S16 streams into one mixed writer to a vani sink. `MshRouter` opens/drives a real vani PCM device — `msh_router_open` (`audio_open_playback` → `audio_set_params` → `audio_prepare`), `msh_router_pump` → `audio_write` with `-EPIPE` re-prepare recovery, `msh_router_close` (drain + close). Vendors `vendor/vani-core.cyr` (provenance vani 1.0.0). `programs/pump_probe.cyr` **confirmed working on real hardware** (2026-07-06, remote session — sink open → pump → drain clean); degrades clean without `audio`-group access. |
| jalwa / agnoshi | not yet integrated | jalwa Rust→Cyrius port pending; agnoshi has no audio path. |

## Shipped Releases

| Tag | Date | Highlights |
|-----|------|------------|
| `1.0.0` | 2026-07-06 | **Stable.** cyrius pin `6.4.3` → `6.4.10`; full `vani_*` API frozen under SemVer (dhvani 2.1.2 validates the full surface; mishran 0.2.0 wires the core sink). api-surface baseline reflowed + refrozen at 106 (the `audio_set_params_full/5` baseline entry was a 2-line-signature tool artifact — the fn has been arity 6 since 0.3.0; reflowed to one line, corrected to `/6`). 258/258, 0 warnings. |
| `0.9.9` | 2026-07-04 | All-stdlib cut — dropped `[deps.yukti]` / `[deps.patra]` git overrides and `cyrius.lock` (vani/yukti/patra now stdlib in cyrius 6.4.3). Full `vani_*` API builds + runs on AGNOS. |
| `0.9.7` | 2026-07-04 | AGNOS backend for the `audio_*` PCM shim (`#ifdef CYRIUS_TARGET_AGNOS` per-seam split → sovereign `snd_*` #64-69 band); `programs/vanitone.cyr` Gate-4 bring-up, QEMU-validated. cyrius pin `6.3.5` → `6.4.2`. |
| `0.9.6` | 2026-06-29 | cyrius pin `6.2.1` → `6.3.5`; yukti `2.2.4` → `2.2.7`; added stdlib `chrono`. |
| `0.9.1` | 2026-05-01 | `core` distribution profile added (`dist/vani-core.cyr`). |
| `0.3.0` | 2026-04-30 | First public release. |

## Bootstrap Chain

Vani depends on:

```
cyrius (6.4.10)
  └─ stdlib — syscalls / string / alloc / str / fmt / vec / io / fs /
             args / hashmap / tagged / fnptr / freelist / process /
             chrono / sakshi / yukti / patra / atomic / sync /
             thread_local
```

No external (non-cyrius, non-AGNOS) git deps — vani is **all-stdlib** as
of 0.9.9. `patra` carries `target = "linux"` (yukti's `device_db`
backend is Linux-only; agnos gates it off).
