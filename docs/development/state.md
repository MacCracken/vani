# Vani — Live State Snapshot

> **Refreshed every release.** This file holds volatile state — current
> version, test/bench counts, dist bundle size, real-HW verification
> hosts, in-flight items, recent shipped releases, downstream
> consumers. Durable rules live in [`CLAUDE.md`](../../CLAUDE.md).
> Historical narrative lives in [`CHANGELOG.md`](../../CHANGELOG.md).

## Release

| Field | Value |
|-------|-------|
| Current version | `1.1.1` (stable — `vani_*` frozen under SemVer; 1.1.1 is a **patch**: cyrius pin `6.4.10`→`6.4.49` (staging the 6.4.50 fold-in) + the agnos `vani_mixer_open` `sys_open`-shape fix, no API change) |
| Released | 2026-07-11 |
| Cyrius toolchain pin | `6.4.49` |
| Dependency model | **all-stdlib** — no git overrides, no `cyrius.lock`. `yukti` + `patra` (and patra's transitive `atomic` / `sync` / `thread_local`) are stdlib modules as of the 0.9.9 all-stdlib cut (cyrius ≥ 6.4.3 bundles vani/yukti/patra) |
| Distribution profiles | full (`dist/vani.cyr`, 82,799 B / 108 symbols) and core (`dist/vani-core.cyr`, 34,653 B / 24 symbols) |
| API surface baseline | `docs/api-surface.snapshot` (108 public fns) — the v1.0 freeze grew additively at 1.1.0 (+`audio_write_nb`/`audio_avail`); `docs/api-surface.core.snapshot` (24) |
| Latest audit | [`docs/audit/2026-07-06-v1.0.0-audit.md`](../audit/2026-07-06-v1.0.0-audit.md) |
| Architectures supported | x86_64-linux, aarch64-linux (since 0.9.0) |

## Test / Bench Counts

| Metric | Value |
|--------|-------|
| CPU test assertions | 259 (groups: error, format, buffer, device, yukti, audit-2026-04-30, hw_params, hw_refine, mixer, v0.4.0 state + sw_params) |
| CPU benchmarks | 13 (format / ring / hwp / negotiate paths) |
| Real-HW programs | 8 (`smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`) |
| Bench history baseline | commit `e031c0d` (2026-04-30 v0.1.0); latest row `59dd681` (2026-05-21, v0.9.4). The cyrius bench-CSV µs 10× bug is **fixed in 6.4.10** (`ring_200ms_playback` CSV now `80916` ≈ 80.9 µs, matching human-readable) — CSV rows are trustworthy again and may be appended. |

## Build Artifacts

| Artifact | Size | Notes |
|----------|------|-------|
| `dist/vani.cyr` (full profile) | 82,799 B / 2251 lines (v1.1.1) | Full consumer-facing bundle: 108 public symbols across alsa/error/format/buffer/device/playback/capture/mixer. Grew from v0.9.1's 76 KB with the 0.9.7 agnos `#ifdef` backend branches, +2 with the 1.1.0 non-blocking sink API, then +11 lines at 1.1.1 with the agnos mixer-open `#ifdef` fail-closed branch. |
| `dist/vani-core.cyr` (core profile) | 34,653 B / 939 lines (v1.1.1) | Playback-only single-module bundle: 24 `audio_*` symbols from `src/alsa.cyr` only (incl. the agnos backend + the 1.1.0 `audio_write_nb`/`audio_avail` non-blocking pair). Byte-unchanged at 1.1.1 (the mixer fix is not in the core profile; only the version stamp moved). ~58% smaller than full. |
| `build/vani_smoke` (DCE) | ~308,857 B NOPed at link | x86_64 ELF link-check binary |
| `build/vani_smoke-aarch64` | (built per cut) | aarch64 ELF link-check binary (since 0.9.0) |
| `dist/vani.deps` / `dist/vani-core.deps` | 15 / 3 stdlib leaves | cyrius distlib sidecars (auto-generated, consumed by consumers' `cyrius deps`); committed alongside the bundles. 6.4.49 records minimal transitive *roots*: the full profile needs 15, the single-module core profile 3 (`string`/`alloc`/`tagged`; was a flattened 15 under 6.4.10, same resolved closure for consumers). |

## Real-HW Verification

| Host | Cards / Devices | Status |
|------|-----------------|--------|
| Dev box (HDA Generic + HDMI + ACP) | 8 PCM endpoints across cards 0/1/2 | All 8 programs PASS as of 0.3.0 (run inside a desktop audio session — the `/dev/snd/pcm*` nodes are `root:audio`, so a non-session shell without `audio`-group/logind-ACL access sees open-EACCES and the programs degrade clean) |
| First playback target | card 1 device 0 / `pci:0000:04:00.6:dev0:p` (ALC897 Analog) | `probe`, `devices`, `tone` round-trip clean |
| **Consumer audible** (cyrius-doom 0.30.5) | card 1 device 0 (ALC897) | **First audible real-HW consumer** (2026-06-29): DOOM SFX play end-to-end through vani at S16_LE / stereo / 44100 |
| **Consumer sink** (mishran 0.4.1) | card 1 device 0 | `pump_probe` **verified on real HW** (2026-07-06, remote session): router → vani sink open → pump → drain clean. mishran 0.4.1 adds `msh_router_pump_nb` over the new `audio_write_nb`/`audio_avail` — a **non-silent** two-proc tone proven on agnos QEMU (RMS 2146). |

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
> (259 assertions) but not yet exercised by a live consumer.

| Project | Status | Notes |
|---------|--------|-------|
| **dhvani** | **live — FULL `vani_*` surface** | Released **2.1.2**. `src/playback.cyr` bridges dhvani's f64 AudioBuffer ↔ vani's interleaved S16/S24/S32 PCM, exercising the full device path: `vani_open_playback` / `vani_open_capture`, `vani_ring_new` / `_write` / `_read`, `vani_play` / `vani_play_from_ring`, `vani_record` / `_record_to_ring`, `vani_configure`, `vani_format_new`, `vani_alsa_for`, `vani_start`, `vani_close`. References vani through functions only, so it DCE-prunes for vani-free consumers. **This is the consumer that unblocks the full-surface 1.0 freeze.** |
| cyrius-doom | **live + audibly verified on real HW** — core profile | Released **0.30.5** (tagged). DOOM SFX route through `audio_write` in the 35 Hz `audio_tick` loop; audible at S16/stereo/44100 (2026-06-29). Deepest core exerciser: `audio_set_params_full` (period/buffer) + `audio_set_sw_params` + an `audio_open_capture` codec probe. Vendors `vendor/vani-core.cyr`. |
| cyrius-polyomino | **live** — core profile | Released **0.5.1** (tagged). Vendors `vendor/vani-core.cyr`. Piece-lock / line-clear / level-up / top-out SFX → `audio_write`. 6 `audio_*` symbols. |
| cyrius-bb | **live** — core profile | Released **0.8.0** (tagged). Vendors `vendor/vani-core.cyr`. Brick/wall/paddle + lost/over/fanfare SFX → `audio_write_bytes`. 6 `audio_*` symbols. |
| **mishran** | **live — core sink (real-HW + two-proc agnos verified)** | **0.4.1** (released). The AGNOS software audio mixer / routing daemon (मिश्रण — "mixing"): fans many per-app S16 streams into one mixed writer to a vani sink. `MshRouter` opens/drives a real vani PCM device — `msh_router_open` (`audio_open_playback` → `audio_set_params` → `audio_prepare`), `msh_router_pump` → blocking `audio_write` (single-proc, `-EPIPE` recovery) **and** `msh_router_pump_nb` → `audio_avail`-gated `audio_write_nb` (multi-proc, cooperative — new in mishran 0.4.1 / vani 1.1.0), `msh_router_close` (drain + close). Vendors `vendor/vani-core.cyr` (provenance vani 1.1.0). `pump_probe` confirmed on real HW (2026-07-06); a **two-proc tone** (client → loopback → mixer → vani → HDA) proven non-silent on agnos QEMU (2026-07-10, RMS 2146). |
| jalwa / agnoshi | not yet integrated | jalwa Rust→Cyrius port pending; agnoshi has no audio path. |

## Shipped Releases

| Tag | Date | Highlights |
|-----|------|------------|
| `1.1.1` | 2026-07-11 | **Patch — toolchain + agnos mixer fix.** cyrius pin `6.4.10` → `6.4.49` (staging the 6.4.50 fold-in; no source change needed to build clean). Fixed the P1 agnos `vani_mixer_open` bug: the Linux 3-arg `sys_open(path, 2, 0)` shape mis-opened a 2-byte path on agnos's `(name, namelen, flags)` `sys_open` — now an `#ifdef CYRIUS_TARGET_AGNOS` fail-closed branch (no `/dev/snd/control*` on agnos), mirroring `audio_open_capture`. `dist/vani-core.deps` tightened 15→3 roots. 259/259, 0 warnings; x86_64 / aarch64 / agnos all build clean. |
| `1.1.0` | 2026-07-10 | **Non-blocking sink API for multi-proc audio.** Added `audio_write_nb` (`snd_write` NONBLOCK #66) + `audio_avail` (`snd_avail` #69) to the core `audio_*` surface — backward-compatible additions (surface 106→108 full / 22→24 core; snapshots updated). Lets a cooperative caller write when the DAC ring has room + `sched_yield` when it doesn't, so two procs share the one hardware writer. First consumer: mishran 0.4.1's `msh_router_pump_nb`, proven two-proc on agnos (client → loopback → mixer → vani → HDA, RMS 2146). agnos-only; Linux delegates to `audio_write`. No breaking change. |
| `1.0.0` | 2026-07-06 | **Stable.** cyrius pin `6.4.3` → `6.4.10`; full `vani_*` API frozen under SemVer (dhvani 2.1.2 validates the full surface; mishran 0.2.0 wires the core sink). api-surface baseline reflowed + refrozen at 106 (the `audio_set_params_full/5` baseline entry was a 2-line-signature tool artifact — the fn has been arity 6 since 0.3.0; reflowed to one line, corrected to `/6`). 258/258, 0 warnings. |
| `0.9.9` | 2026-07-04 | All-stdlib cut — dropped `[deps.yukti]` / `[deps.patra]` git overrides and `cyrius.lock` (vani/yukti/patra now stdlib in cyrius 6.4.3). Full `vani_*` API builds + runs on AGNOS. |
| `0.9.7` | 2026-07-04 | AGNOS backend for the `audio_*` PCM shim (`#ifdef CYRIUS_TARGET_AGNOS` per-seam split → sovereign `snd_*` #64-69 band); `programs/vanitone.cyr` Gate-4 bring-up, QEMU-validated. cyrius pin `6.3.5` → `6.4.2`. |
| `0.9.6` | 2026-06-29 | cyrius pin `6.2.1` → `6.3.5`; yukti `2.2.4` → `2.2.7`; added stdlib `chrono`. |
| `0.9.1` | 2026-05-01 | `core` distribution profile added (`dist/vani-core.cyr`). |
| `0.3.0` | 2026-04-30 | First public release. |

## Bootstrap Chain

Vani depends on:

```
cyrius (6.4.49)
  └─ stdlib — syscalls / string / alloc / str / fmt / vec / io / fs /
             args / hashmap / tagged / fnptr / freelist / process /
             chrono / sakshi / yukti / patra / atomic / sync /
             thread_local
```

No external (non-cyrius, non-AGNOS) git deps — vani is **all-stdlib** as
of 0.9.9. `patra` carries `target = "linux"` (yukti's `device_db`
backend is Linux-only; agnos gates it off).
