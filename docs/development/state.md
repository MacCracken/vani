# Vani — Live State Snapshot

> **Refreshed every release.** This file holds volatile state — current
> version, test/bench counts, dist bundle size, real-HW verification
> hosts, in-flight items, recent shipped releases, downstream
> consumers. Durable rules live in [`CLAUDE.md`](../../CLAUDE.md).
> Historical narrative lives in [`CHANGELOG.md`](../../CHANGELOG.md).

## Release

| Field | Value |
|-------|-------|
| Current version | `1.1.4` (stable — `vani_*` frozen under SemVer; 1.1.4 is a **patch**: cyrius pin `6.5.5`→`6.5.31` + the stdlib that came with it, **zero semantic source change** (formatter whitespace reflow + one comment cross-reference), no API change) |
| Released | 2026-08-20 |
| Cyrius toolchain pin | `6.5.31` |
| Dependency model | **all-stdlib** — no git overrides, no `cyrius.lock`. `yukti` + `patra` (and patra's transitive `atomic` / `sync` / `thread_local`) are stdlib modules as of the 0.9.9 all-stdlib cut. **The pin is the supply chain**: `cyrius build` resolves `include "lib/…"` from `$CYRIUS_HOME/versions/<pin>/lib`, *not* from the vendored `./lib/` — established by the 1.1.2 audit (canary in `lib/alloc.cyr`) and re-confirmed at 1.1.4 by a deliberate syntax error in `./lib/tagged.cyr` that the build sailed past, byte-identical. `./lib/` is editor/IDE support and the source of the `shadows version-pinned` warning only |
| Distribution profiles | full (`dist/vani.cyr`, 83,005 B / 2253 lines / 108 symbols) and core (`dist/vani-core.cyr`, 34,801 B / 941 lines / 24 symbols) |
| API surface baseline | `docs/api-surface.snapshot` (108 public fns) — `cyrius_api_surface --scope=project` reports "surface matches snapshot exactly" at 1.1.4; `docs/api-surface.core.snapshot` (24) |
| Latest audit | [`docs/audit/2026-08-20-v1.1.4-audit.md`](../audit/2026-08-20-v1.1.4-audit.md) — toolchain/dep sweep across 26 cyrius releases, UAPI re-pin vs kernel 7.1.8, CVE sweep, CI-gate audit. Prior: [`2026-07-19-v1.1.2-audit.md`](../audit/2026-07-19-v1.1.2-audit.md) (1.1.3 shipped without one — gap closed here) |
| Architectures supported | x86_64-linux, aarch64-linux (since 0.9.0); agnos target builds clean (not a CI leg) |

## Test / Bench Counts

| Metric | Value |
|--------|-------|
| CPU test assertions | 259 (groups: error, format, buffer, device, yukti, audit-2026-04-30, hw_params, hw_refine, mixer, v0.4.0 state + sw_params) |
| CPU benchmarks | 13 (format / ring / hwp / negotiate paths) |
| Real-HW programs | 8 (`smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`) |
| Bench history baseline | commit `e031c0d` (2026-04-30 v0.1.0); latest row `ddb488b` (2026-08-20, v1.1.4) against the prior `31d5f08` (2026-07-19, v1.1.2). At 1.1.4, three runs under the pinned 6.5.31 toolchain read `ring_200ms_playback` 83.9 / 85.9 / 85.6 µs against the 84.1 µs 1.1.2 row — inside run-to-run noise, and measured on a machine under heavy concurrent load. `hwp_init_any` improved 991 → 934-956 ns, `ring_read_64b` 328 → 316-327 ns. Nothing in this bump touches a benched code path. |

## Build Artifacts

| Artifact | Size | Notes |
|----------|------|-------|
| `dist/vani.cyr` (full profile) | 83,005 B / 2253 lines (v1.1.4) | Full consumer-facing bundle: 108 public symbols across alsa/error/format/buffer/device/playback/capture/mixer. `+206 B` vs 1.1.3 — the version stamp, the formatter's continuation-indent reflow, and the 2-line comment cross-reference that closed the lint deferral. `git diff -w` against 1.1.3 is **8 comment lines and the version stamp, nothing else**, which is the proof that 1.1.4 carries no semantic source change. |
| `dist/vani-core.cyr` (core profile) | 34,801 B / 941 lines (v1.1.4) | Playback-only single-module bundle: 24 `audio_*` symbols from `src/alsa.cyr` only. `+148 B` vs 1.1.3, same whitespace-plus-comment-plus-stamp story. ~58% smaller than full. |
| `build/vani_smoke` (DCE) | **506,816 B** binary; 351,545 B NOPed / 1307 unreachable fns (v1.1.4, cyrius 6.5.31) | x86_64 ELF link-check binary. A 2×2 A/B over `(cycc version) × (pinned stdlib snapshot)` separates the growth exactly: **+30,008 B from the stdlib snapshot** (identical delta under either compiler) and **+4,096 B from cycc** (identical delta under either stdlib). Nominal 1.1.3 (cycc 6.5.5 + stdlib 6.5.5) was 472,712 B, so the full nominal delta is +34,104 B. The cycc axis is +4,064 B of real text/rodata (R+E LOAD `0x64d00`→`0x65ce0`) rounded to one 4 KiB page; the RW segment is byte-identical. Reachable-fn count unchanged — codegen density, not new code. |
| `build/vani_smoke-aarch64` | **744,232 B** binary; 579,420 B NOPed / 1307 unreachable fns (v1.1.4) | aarch64 ELF link-check binary (since 0.9.0) — valid stripped ARM aarch64 ELF. Was 677,336 B at the 6.5.5 pin. |
| `build/vani_smoke-agnos` | **489,624 B**; 333,407 B NOPed / 1315 unreachable fns (v1.1.4) | agnos target (`--agnos`, not a CI leg). Was 451,584 B at the 6.5.5 pin. **Zero warnings** — and zero at *both* ends of this bump, so the 15 stdlib-`lib/yukti.cyr` warnings the 1.1.2 audit documented were already resolved upstream before 6.5.5; 1.1.4 did not fix them and does not claim to. |
| `dist/vani.deps` / `dist/vani-core.deps` | **21 / 4** stdlib leaves | cyrius distlib sidecars (auto-generated, consumed by consumers' `cyrius deps`); committed alongside the bundles. Grew at 1.1.4 from 15 / 3: the full profile gained `freelist`, `process`, `patra`, `atomic`, `sync`, `thread_local` (the yukti/patra transitive chain, previously under-reported); core gained `syscalls`, which `src/alsa.cyr` plainly needs for `syscall(SYS_IOCTL, …)` and `sys_open` and which 1.1.1's 15→3 tightening had over-trimmed. More correct, not churn. |

## Toolchain / CI Notes

| Item | State |
|------|-------|
| CI format gate | **Fixed at 1.1.4.** The step ran `diff <(cyrius fmt "$f") "$f"`, correct through 1.1.3. In the 6.5.6–6.5.31 window `cyrius fmt <file>` changed to format **in place** and print nothing, so the gate compared an empty stream against every file — guaranteed red, and on a writable checkout it silently rewrote sources. Now `cyrius fmt <file> --check` (exit 0/1, writes nothing). **Do not substitute the bare `cyrfmt --check` binary** — it reported CLEAN on the same six files `cyrius fmt --check` correctly flagged, so it is the weaker check. |
| CI lint gate | Extended at 1.1.4 to fail on `N untracked deferrals` as well as `warn ` lines. cyrlint exits 0 on deferrals, so the gate has to catch them. vani's one hit (`src/alsa.cyr`, a stale "filed as audit follow-up" sentence for work closed at 0.3.0) is closed; the file now cross-references `docs/audit/2026-04-30-audit.md`. |
| cyrlint surface | **Byte-identical between 6.5.5 and 6.5.31** on vani's sources (2 `sys_open` notes, 1 deferral, 0 warnings under both) — this bump adds no new lint surface. The deferral class predates 6.5.5; closing it at 1.1.4 is cleanup, not toolchain-forced. |
| api-surface check | `cyrius_api_surface --scope=project` → 108, matches snapshot exactly. **Still not wired into CI** — the v1.0.0 SemVer freeze is enforced by hand. Filed P2. |
| Open P1 | **`enum AlsaHwParam` interval indices are +2 off the kernel UAPI** (`src/alsa.cyr:156-169`). No wire impact — all 12 use sites compute `PARAM - FIRST_INTERVAL` and `rmask` is all-ones — but it violates "kernel UAPI is the spec". Found by the 1.1.4 sweep; deferred out of 1.1.4 to preserve the patch's inertness proof. See roadmap P1. |

## Real-HW Verification

| Host | Cards / Devices | Status |
|------|-----------------|--------|
| Dev box (HDA Generic + HDMI + ACP) | 8 PCM endpoints across cards 0/1/2 | All 8 programs PASS as of 0.3.0 (run inside a desktop audio session — the `/dev/snd/pcm*` nodes are `root:audio`, so a non-session shell without `audio`-group/logind-ACL access sees open-EACCES and the programs degrade clean) |
| First playback target | card 1 device 0 / `pci:0000:04:00.6:dev0:p` (ALC897 Analog) | `probe`, `devices`, `tone` round-trip clean |
| Enumerator re-check (1.1.2) | 8 PCM endpoints across cards 0/1/2 | `vani_devices` under yukti 2.2.10 enumerated all 8 endpoints, matching the documented baseline exactly. |
| **Enumerator re-check (1.1.4)** | 8 PCM endpoints across cards 0/1/2 | `vani_devices` under **yukti 2.3.8** enumerates all 8 endpoints, matching the documented baseline **exactly** — same cards, devices, directions, drivers, names and `hw_id`s (`pci:0000:04:00.6:dev{0,2}` ALC897 ×3, `pci:0000:04:00.1:dev{3,7,8,9}` HDMI 0-3, `card2_dev0_c` acp). The yukti 2.3.2 → 2.3.8 bump does not disturb discovery. PCM open returned the documented non-session EACCES — the `/dev/snd/*` nodes are `root:audio` and the logind ACL grants `sddm`, not this shell — and **all 8 programs degraded closed with no crash**: `devices`/`probe` exit 1 with `open: FAIL`, `caps`/`throughput`/`mixer_test`/`latency_test` print `open: FAIL` and exit 0. Unchanged behavior, not a regression. |
| **Consumer audible** (cyrius-doom 0.30.5) | card 1 device 0 (ALC897) | **First audible real-HW consumer** (2026-06-29): DOOM SFX play end-to-end through vani at S16_LE / stereo / 44100 |
| **Consumer sink** (mishran 0.4.1) | card 1 device 0 | `pump_probe` **verified on real HW** (2026-07-06, remote session): router → vani sink open → pump → drain clean. mishran 0.4.1 adds `msh_router_pump_nb` over `audio_write_nb`/`audio_avail`. ⛔ **RETRACTED 2026-08-03** — this row previously claimed "a **non-silent** two-proc tone proven on agnos QEMU (RMS 2146)". That was a **FALSE GREEN**, produced by the `MISHRAN_DUPLEX_SELFTEST` kernel hook's `net_ip = 0x7F000001` assignment (the only reason the client's loopback TCP connect could match a 4-tuple on agnos); the hook and its smoke are deleted. **The real-HW `pump_probe` result above is unaffected and stands.** `audio_write_nb` / `audio_avail` themselves are sound and unchanged — they simply have no valid agnos multi-proc demonstration, which must be re-established over the agnos socket (`anu`). See agnos `docs/development/planning/ipc.md` §9-§10. |

| Hardware class | status | Tracked in |
|----------------|--------|------------|
| Onboard analog (HDA Generic, ALC897) | Verified + audible | — |
| HDMI audio (HDA Generic) | Enumerated by `vani_devices`, not yet round-tripped | roadmap post-1.0 (HW-gated) |
| USB audio interface | Not yet tested | roadmap post-1.0 (HW-gated) |

## In-flight

| Item | Target | Notes |
|------|--------|-------|
| Audible real-HW round-trip at 1.1.4 | opportunistic | `vani_devices` re-confirmed enumeration under yukti 2.3.8, but every PCM open on this box currently returns EACCES (logind ACL grants `sddm`, not this shell), so no tone was pushed at 1.1.4. The last audible confirmation is cyrius-doom 0.30.5 (2026-06-29). Re-run `./build/vani_tone` from inside a desktop audio session when convenient. |
| USB + HDMI real-HW round-trip | post-1.0 (HW-gated) | The v1.0 freeze criterion #1 residual. Same frozen code path as onboard HDA; verification needs USB-class / HDMI hardware access. Does **not** touch the frozen API. |
| `snd_pcm_status` comment vs pinned table | 1.2.0 | `audio_get_state` declares `var status[192]` under a comment claiming 192 bytes; the pinned table and the kernel probe both say 152. Over-allocated, therefore safe — but a wrong comment on a UAPI-pinned buffer. Filed by the 1.1.2 audit (INFO #3). |
| XRUN-rate stress benchmark | optional post-1.0 | Reproducing CPU contention reliably needs harness setup beyond a release gate. |
| Portable `_clock_monotonic()` for throughput / latency_test | optional post-1.0 | `programs/throughput.cyr` / `latency_test.cyr` still use raw `syscall(228)` (x86_64-only by design); fixes when an aarch64 dev host with audio HW exists. |

## Downstream Consumers

> v1.0.0 froze the **full `vani_*` surface** under SemVer. The full
> ring/capture/playback/device/format surface is live-consumer
> validated by **dhvani**. The two remaining consumer-unvalidated
> corners are `vani_open_yukti` (the yukti adapter) and
> `src/mixer.cyr` (the hardware volume/mute control surface) — both
> internally test-covered (259 assertions) but not yet exercised by a
> live consumer.

| Project | Status | Notes |
|---------|--------|-------|
| **dhvani** | **live — FULL `vani_*` surface** | Released **2.1.2**. `src/playback.cyr` bridges dhvani's f64 AudioBuffer ↔ vani's interleaved S16/S24/S32 PCM, exercising the full device path: `vani_open_playback` / `vani_open_capture`, `vani_ring_new` / `_write` / `_read`, `vani_play` / `vani_play_from_ring`, `vani_record` / `_record_to_ring`, `vani_configure`, `vani_format_new`, `vani_alsa_for`, `vani_start`, `vani_close`. References vani through functions only, so it DCE-prunes for vani-free consumers. **This is the consumer that unblocks the full-surface 1.0 freeze.** |
| cyrius-doom | **live + audibly verified on real HW** — core profile | Released **0.30.5** (tagged). DOOM SFX route through `audio_write` in the 35 Hz `audio_tick` loop; audible at S16/stereo/44100 (2026-06-29). Deepest core exerciser: `audio_set_params_full` (period/buffer) + `audio_set_sw_params` + an `audio_open_capture` codec probe. Vendors `vendor/vani-core.cyr`. |
| cyrius-polyomino | **live** — core profile | Released **0.5.1** (tagged). Vendors `vendor/vani-core.cyr`. Piece-lock / line-clear / level-up / top-out SFX → `audio_write`. 6 `audio_*` symbols. |
| cyrius-bb | **live** — core profile | Released **0.8.0** (tagged). Vendors `vendor/vani-core.cyr`. Brick/wall/paddle + lost/over/fanfare SFX → `audio_write_bytes`. 6 `audio_*` symbols. |
| **mishran** | **live — core sink (real-HW verified; two-proc agnos claim RETRACTED)** | **0.4.1** (released). The AGNOS software audio mixer / routing daemon (मिश्रण — "mixing"): fans many per-app S16 streams into one mixed writer to a vani sink. `MshRouter` opens/drives a real vani PCM device — `msh_router_open` (`audio_open_playback` → `audio_set_params` → `audio_prepare`), `msh_router_pump` → blocking `audio_write` (single-proc, `-EPIPE` recovery) **and** `msh_router_pump_nb` → `audio_avail`-gated `audio_write_nb` (multi-proc, cooperative), `msh_router_close` (drain + close). Vendors `vendor/vani-core.cyr` (provenance vani 1.1.0). `pump_probe` confirmed on real HW (2026-07-06). ⛔ **RETRACTED 2026-08-03** — this entry previously claimed a **two-proc tone** "proven non-silent on agnos QEMU (2026-07-10, RMS 2146)". **FALSE GREEN**: it required the `MISHRAN_DUPLEX_SELFTEST` kernel hook's `net_ip = 0x7F000001` assignment for the loopback connect to complete at all; hook + smoke deleted. mishran's own CHANGELOG retracts the same claim at its `[0.4.1]` entry. TCP-on-loopback is retired as the local transport; re-proof belongs on the agnos socket (`anu`) — agnos `docs/development/planning/ipc.md` §9-§10. The real-HW sink verification is untouched. |
| jalwa / agnoshi | not yet integrated | jalwa Rust→Cyrius port pending; agnoshi has no audio path. |

## Shipped Releases

| Tag | Date | Highlights |
|-----|------|------------|
| `1.1.4` | 2026-08-20 | **Patch — toolchain + stdlib refresh across 26 cyrius releases, zero semantic source change.** cyrius pin `6.5.5` → `6.5.31`; yukti `2.3.2` → `2.3.8`, patra `1.12.12` → `1.13.9`, sakshi `2.4.7` → `2.4.11`. 40 resolved modules (24 changed), all byte-identical to the pinned snapshot. A clean 2×2 A/B splits the binary growth exactly: +30,008 B stdlib, +4,096 B cycc, perfectly orthogonal. Both dist bundles `git diff -w` clean apart from the version stamp; API surface holds at 108. 259/259, 0 lint warnings, 0 untracked deferrals, vet clean, x86_64 / aarch64 / agnos all build clean with zero warnings. Fixed the **CI format gate**, which the toolchain bump had silently inverted (`cyrius fmt <file>` now formats in place and prints nothing — the old `diff <(…)` form was a guaranteed red that also rewrote sources); applied the resulting formatter reflow (whitespace only, 59/59 across 6 files); closed the last untracked lint deferral. Also documented that `cyrius build` resolves stdlib from the **pinned snapshot**, not vendored `./lib/`. UAPI re-pinned and CVE-swept — closes the audit gap 1.1.3 left. |
| `1.1.3` | 2026-08-02 | **Patch — toolchain catch-up.** cyrius pin `6.4.67` → `6.5.5`, cut together with the wider desktop stack so one compiler builds the whole burn. Notable window content: **6.5.1** made overload-suffix arity a hard error (was a warning); **6.4.75** fixed `fn_table` growth past 8192 corrupting six fn-indexed side tables; **6.5.0** added file-scoped `private` / per-item `public`; **6.4.82** completed the agnos GPU syscall wrapper band `#82`-`#95`. Host + `--agnos` builds green, suite passes, distlib regenerated. Shipped **without** an audit doc — gap closed at 1.1.4. |
| `1.1.2` | 2026-07-19 | **Patch — toolchain + stdlib dep refresh, zero source change.** cyrius pin `6.4.49` → `6.4.67`; yukti `2.2.9` → `2.2.10` (version stamp only), patra `1.12.9` → `1.12.12`. A 2×2 `(cycc) × (stdlib)` A/B proved **cycc version had zero effect on vani's emitted bytes** in that window. One behavior delta: `ALLOC_MAX` 256 MiB → 2 GiB, reaching `vani_ring_new` only in (256 MiB, 1 GiB] — a window nothing enters, failing safe. 259/259, 0 warnings. UAPI re-pinned (18 ioctls + 8 struct sizes, 0 mismatches vs kernel 7.1), 8 in-window kernel audio CVEs triaged clean. |
| `1.1.1` | 2026-07-11 | **Patch — toolchain + agnos mixer fix.** cyrius pin `6.4.10` → `6.4.49`. Fixed the P1 agnos `vani_mixer_open` bug: the Linux 3-arg `sys_open(path, 2, 0)` shape mis-opened a 2-byte path on agnos's `(name, namelen, flags)` `sys_open` — now an `#ifdef CYRIUS_TARGET_AGNOS` fail-closed branch. `dist/vani-core.deps` tightened 15→3 roots (over-trimmed; corrected to 4 at 1.1.4). 259/259, 0 warnings. |
| `1.1.0` | 2026-07-10 | **Non-blocking sink API for multi-proc audio.** Added `audio_write_nb` (`snd_write` NONBLOCK #66) + `audio_avail` (`snd_avail` #69) to the core `audio_*` surface — backward-compatible additions (surface 106→108 full / 22→24 core). First consumer: mishran 0.4.1's `msh_router_pump_nb`. ⛔ **RETRACTED 2026-08-03** — the "proven two-proc on agnos" claim was a **FALSE GREEN** off the `MISHRAN_DUPLEX_SELFTEST` kernel hook's `net_ip = 0x7F000001` rigging (hook + smoke deleted). The API additions are real and unchanged; only the agnos multi-proc demonstration is void. agnos-only; Linux delegates to `audio_write`. |
| `1.0.0` | 2026-07-06 | **Stable.** cyrius pin `6.4.3` → `6.4.10`; full `vani_*` API frozen under SemVer (dhvani 2.1.2 validates the full surface; mishran 0.2.0 wires the core sink). api-surface baseline reflowed + refrozen at 106. 258/258, 0 warnings. |
| `0.9.9` | 2026-07-04 | All-stdlib cut — dropped `[deps.yukti]` / `[deps.patra]` git overrides and `cyrius.lock` (vani/yukti/patra now stdlib in cyrius 6.4.3). Full `vani_*` API builds + runs on AGNOS. |
| `0.9.7` | 2026-07-04 | AGNOS backend for the `audio_*` PCM shim (`#ifdef CYRIUS_TARGET_AGNOS` per-seam split → sovereign `snd_*` #64-69 band); `programs/vanitone.cyr` Gate-4 bring-up, QEMU-validated. cyrius pin `6.3.5` → `6.4.2`. |
| `0.9.6` | 2026-06-29 | cyrius pin `6.2.1` → `6.3.5`; yukti `2.2.4` → `2.2.7`; added stdlib `chrono`. |
| `0.9.1` | 2026-05-01 | `core` distribution profile added (`dist/vani-core.cyr`). |
| `0.3.0` | 2026-04-30 | First public release. |

## Bootstrap Chain

Vani depends on:

```
cyrius (6.5.31)
  └─ stdlib — syscalls / string / alloc / str / fmt / vec / io / fs /
             args / hashmap / tagged / fnptr / freelist / process /
             chrono / sakshi / yukti (2.3.8) / patra (1.13.9) /
             atomic / sync / thread_local
```

Those 21 declared leaves resolve to **40 modules** on disk (platform
variants: `alloc_agnos` / `_macos` / `_windows`, `args_*`, `fs_win`,
`process_*`, `sync_*`, `syscalls_*`, plus transitive `mmap` and
`result`).

No external (non-cyrius, non-AGNOS) git deps — vani is **all-stdlib** as
of 0.9.9. `patra` carries `target = "linux"` (yukti's `device_db`
backend is Linux-only; agnos gates it off).
