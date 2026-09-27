# Vani — Live State Snapshot

> **Refreshed every release.** This file holds volatile state — current
> version, test/bench counts, dist bundle size, real-HW verification
> hosts, in-flight items, recent shipped releases, downstream
> consumers. Durable rules live in [`CLAUDE.md`](../../CLAUDE.md).
> Historical narrative lives in [`CHANGELOG.md`](../../CHANGELOG.md).

## Release

| Field | Value |
|-------|-------|
| Current version | `1.2.7` (stable — **patch**: both bundles build for Windows/PE again (a `CYRIUS_TARGET_WIN` refusal arm in `_audio_open_pcm`); every ALSA ioctl goes through a private fail-closed `_audio_ioctl`, so the agnos build no longer needs yukti's placeholder `SYS_IOCTL`; the aarch64 FIFO tests are a counted skip until cyrius 6.6.8. Pin `6.6.2` → `6.6.6`. No public API change) |
| Released | 2026-09-27 |
| Cyrius toolchain pin | `6.6.6` (since 1.2.7; was `6.6.2`) |
| Dependency model | **all-stdlib** — no git overrides, no `cyrius.lock`. `yukti` + `patra` (and patra's transitive `atomic` / `sync` / `thread_local`) are stdlib modules as of the 0.9.9 all-stdlib cut. **The pin is the supply chain**: `cyrius build` resolves `include "lib/…"` from `$CYRIUS_HOME/versions/<pin>/lib`, *not* from the vendored `./lib/` — established by the 1.1.2 audit (canary in `lib/alloc.cyr`) and re-confirmed at 1.1.4 by a deliberate syntax error in `./lib/tagged.cyr` that the build sailed past, byte-identical. `./lib/` is editor/IDE support and the source of the `shadows version-pinned` warning only |
| Distribution profiles | full (`dist/vani.cyr`, 114,403 B / **109** symbols) and core (`dist/vani-core.cyr`, 50,784 B / **25** symbols) |
| API surface baseline | `docs/api-surface.snapshot` (**109** public fns) — `cyrius_api_surface --scope=project` reports "surface matches snapshot exactly"; `docs/api-surface.core.snapshot` (**25**). Grew by exactly one additive fn at 1.2.0 (`audio_set_params_fmt`), which is why 1.2.0 is a minor. **Now gated in CI** — the gate was verified to exit 1 on both a removal and an arity change |
| Latest audit | [`docs/audit/2026-09-27-v1.2.6-audit.md`](../audit/2026-09-27-v1.2.6-audit.md) — release pass: the new open sequence, UAPI re-pinned against the 7.2 headers and 7.3-rc4 (0 mismatches), CVE window 2026-08-20 → 2026-09-27 (81 NVD records, none vani can mitigate). 1.2.3-1.2.5 shipped without audit docs; this one covers their window. Priors: [`v1.2.2`](../audit/2026-08-20-v1.2.2-audit.md) (structural close-out), [`v1.2.1`](../audit/2026-08-20-v1.2.1-audit.md) (code-level tail), [`v1.2.0`](../audit/2026-08-20-v1.2.0-audit.md) (the sweep — 5 lenses + adversarial verification, 50 of 55 findings re-rated) |
| Architectures supported | x86_64-linux, aarch64-linux (since 0.9.0); agnos target builds clean (not a CI leg). Both bundles also compile for Windows/PE and Mach-O (x86 + arm64), where the opens return the null handle — re-verified at 1.2.7 (not CI legs) |

## Test / Bench Counts

| Metric | Value |
|--------|-------|
| CPU test assertions | **909** on x86_64; on aarch64 (qemu-user) **898** + 2 tests (11 assertions) counted as SKIP since 1.2.7 — the named-FIFO tests need `mknodat`, which cyrius 6.6.6 cannot issue on aarch64 (6.6.8 adds `sys_mknodat`) (259 at 1.1.4, 775 at 1.2.0, 778 at 1.2.1, 893 at 1.2.2). **The exit status gates CI since 1.2.6** — through 1.2.5 `main()` discarded the failure count, so no assertion could fail CI. Reference coverage **100%** — 109/109 fns, 8/8 files (re-checked at 1.2.6), up from 36/108 and 5/8 at 1.1.4. All 140 `src` functions are genuinely *called* from tests, not merely mentioned (`cyrius coverage` counts a mention). Every 1.2.0 repair ships a regression assertion, and the load-bearing ones were validated with negative controls (see CHANGELOG) |
| CPU benchmarks | 13 (format / ring / hwp / negotiate paths) |
| Real-HW programs | 9 (`smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`, `busy_open`) plus `vanitone` (agnos bring-up) — 10 build targets, all clean. `busy_open` added at 1.2.6 |
| Bench history baseline | commit `e031c0d` (2026-04-30 v0.1.0); latest row 2026-08-20 (v1.2.1). **Read cross-row comparisons with care** — the file has no column for measurement session, and the 1.2.1 row was taken on a machine running ~8% slower than the 1.2.0 row: `ring_200ms_playback` reads 91.6 µs vs 84.8 µs on *byte-identical* code. The sound method is a same-session A/B against the previous tag, which for 1.2.1 showed the new range guards cost nothing measurable (`hwp_mask_set_value` 21 vs 21 ns, `hwp_init_any` 1,030 vs 1,008-1,042, `hwp_interval_set_exact` +1 ns). |

## Build Artifacts

| Artifact | Size | Notes |
|----------|------|-------|
| `dist/vani.cyr` (full profile) | 114,403 B (v1.2.7) | Full consumer-facing bundle: **109** public symbols. +843 B over 1.2.6 (113,560 B): the Windows arm and the `_audio_ioctl` bridge, most of it their comments. Was 83,005 B at 1.1.4. |
| `dist/vani-core.cyr` (core profile) | 50,784 B (v1.2.7) | Playback-only single-module bundle from `src/alsa.cyr`: **25** `audio_*` symbols. +885 B over 1.2.6 (49,899 B), same cause. |
| `build/vani_smoke` (DCE) | **118,648 B** (v1.2.7, cyrius 6.6.6) | x86_64 ELF link-check binary. 1.2.6 was 118,464 B on cyrius 6.6.2; the drop from 1.2.2's 515,432 B (cyrius 6.5.32) is the toolchain, not vani. |
| `build/vani_smoke-aarch64` | **876,208 B** (v1.2.7, cyrius 6.6.6) | aarch64 ELF link-check binary — valid stripped ARM aarch64 ELF. 810,520 B at 1.2.6 (cyrius 6.6.2); 744,536 B at 1.2.0 (cyrius 6.5.32). The 1.2.7 test suite runs as an aarch64 build under qemu-user: 898/898 with 2 counted skips. |
| `build/vani_smoke-agnos` | **117,760 B** (v1.2.7, cyrius 6.6.6) | agnos target (`--agnos`, not a CI leg). Was 494,032 B at 1.2.0 (cyrius 6.5.32). |
| `dist/vani.deps` / `dist/vani-core.deps` | 21 / 3 stdlib leaves | Unchanged at 1.2.7. (This row said 21 / 4 through 1.2.2; the committed core sidecar lists 3 — `syscalls`, `string`, `alloc`.) Words in `src/alsa.cyr` comments can inflate the core sidecar and the drift gate will not notice — [`architecture/002`](../architecture/002-distlib-deps-counts-comment-words.md). |
| All 10 programs | 480-535 KB | `smoke`, `probe`, `play_tone`, `caps`, `throughput`, `mixer_test`, `latency_test`, `devices`, `busy_open`, `vanitone` — all build. The only warnings are the three documented `vani_drain` / `vani_drop` / `vani_state` mixed-return notes from `src/device.cyr` (CHANGELOG 1.2.4 Notes). |

## Toolchain / CI Notes

| Item | State |
|------|-------|
| CI format gate | **Fixed at 1.1.4.** The step ran `diff <(cyrius fmt "$f") "$f"`, correct through 1.1.3. In the 6.5.6–6.5.31 window `cyrius fmt <file>` changed to format **in place** and print nothing, so the gate compared an empty stream against every file — guaranteed red, and on a writable checkout it silently rewrote sources. Now `cyrius fmt <file> --check` (exit 0/1, writes nothing). **Do not substitute the bare `cyrfmt --check` binary** — it reported CLEAN on the same six files `cyrius fmt --check` correctly flagged, so it is the weaker check. |
| CI lint gate | Extended at 1.1.4 to fail on `N untracked deferrals` as well as `warn ` lines. cyrlint exits 0 on deferrals, so the gate has to catch them. vani's one hit (`src/alsa.cyr`, a stale "filed as audit follow-up" sentence for work closed at 0.3.0) is closed; the file now cross-references `docs/audit/2026-04-30-audit.md`. |
| cyrlint surface | 0 warnings, 0 untracked deferrals, **1 note** at 1.2.6 (`src/mixer.cyr:97`, the declined `xopen` adoption). The two `alsa.cyr` `raw sys_open w/ literal flags` notes went with the 1.2.6 open rewrite. (Byte-identical between 6.5.5 and 6.5.31, per the 1.1.4 audit.) |
| Open P1 | *None.* The 1.1.4 P1 (`enum AlsaHwParam` +2 off the UAPI) was **fixed at 1.2.0** along with the regression assertions that would have caught it. |
| api-surface CI gate | **Closed at 1.2.0** — `cyrius_api_surface --scope=project` now runs in CI, verified to exit 1 on a removal and on an arity change. |
| CI test gate | **Fixed at 1.2.6.** `tests/tcyr/vani.tcyr` `main()` returned 0 whatever `assert_summary()` reported, so the Test step could fail only on a crash or signal. It now returns 1 on any failure — not the count: an exit status is 8 bits, and `cyrius test` reads anything above 128 as a signal death (measured: 139 failures reported as SIGSEGV, 256 as a pass). |

## Real-HW Verification

| Host | Cards / Devices | Status |
|------|-----------------|--------|
| Dev box (HDA Generic + HDMI + ACP) | 8 PCM endpoints across cards 0/1/2 | All 8 programs PASS as of 0.3.0 (run inside a desktop audio session — the `/dev/snd/pcm*` nodes are `root:audio`, so a non-session shell without `audio`-group/logind-ACL access sees open-EACCES and the programs degrade clean) |
| First playback target | card 1 device 0 / `pci:0000:04:00.6:dev0:p` (ALC897 Analog) | `probe`, `devices`, `tone` round-trip clean |
| Enumerator re-check (1.1.2) | 8 PCM endpoints across cards 0/1/2 | `vani_devices` under yukti 2.2.10 enumerated all 8 endpoints, matching the documented baseline exactly. |
| **Enumerator re-check (1.1.4)** | 8 PCM endpoints across cards 0/1/2 | `vani_devices` under **yukti 2.3.8** enumerates all 8 endpoints, matching the documented baseline **exactly** — same cards, devices, directions, drivers, names and `hw_id`s (`pci:0000:04:00.6:dev{0,2}` ALC897 ×3, `pci:0000:04:00.1:dev{3,7,8,9}` HDMI 0-3, `card2_dev0_c` acp). The yukti 2.3.2 → 2.3.8 bump does not disturb discovery. PCM open returned the documented non-session EACCES — the `/dev/snd/*` nodes are `root:audio` and the logind ACL grants `sddm`, not this shell — and **all 8 programs degraded closed with no crash**: `devices`/`probe` exit 1 with `open: FAIL`, `caps`/`throughput`/`mixer_test`/`latency_test` print `open: FAIL` and exit 0. Unchanged behavior, not a regression. |
| **Consumer audible** (cyrius-doom 0.30.5) | card 1 device 0 (ALC897) | **First audible real-HW consumer** (2026-06-29): DOOM SFX play end-to-end through vani at S16_LE / stereo / 44100 |
| **Consumer sink** (mishran 0.4.1) | card 1 device 0 | `pump_probe` **verified on real HW** (2026-07-06, remote session): router → vani sink open → pump → drain clean. mishran 0.4.1 adds `msh_router_pump_nb` over `audio_write_nb`/`audio_avail`. ⛔ **RETRACTED 2026-08-03** — this row previously claimed "a **non-silent** two-proc tone proven on agnos QEMU (RMS 2146)". That was a **FALSE GREEN**, produced by the `MISHRAN_DUPLEX_SELFTEST` kernel hook's `net_ip = 0x7F000001` assignment (the only reason the client's loopback TCP connect could match a 4-tuple on agnos); the hook and its smoke are deleted. **The real-HW `pump_probe` result above is unaffected and stands.** `audio_write_nb` / `audio_avail` themselves are sound and unchanged — they simply have no valid agnos multi-proc demonstration, which must be re-established over the agnos socket (`anu`). See agnos `docs/development/planning/ipc.md` §9-§10. |
| **Busy-PCM open** (2026-09-26, 1.2.6) | card 1 device 0 playback (ALC897, one subdevice), kernel 7.2.6 | With a second process holding `pcmC1D0p`, 1.2.5's `audio_open_playback` slept until `timeout 5` killed it; the fix returns 0 in 71 µs. `vani_busy_open`: 16/16 playback checks pass (blocking WRITEI / DRAIN, including after XRUN → PREPARE). `probe`, `caps`, `throughput`, `latency_test` pass through the new open. Silent only. **Capture half not run** — this shell had an ACL on `pcmC1D0p` alone. Kernel measurements: [`architecture/001`](../architecture/001-pcm-open-nonblock.md). |

| Hardware class | status | Tracked in |
|----------------|--------|------------|
| Onboard analog (HDA Generic, ALC897) | Verified + audible | — |
| HDMI audio (HDA Generic) | Enumerated by `vani_devices`, not yet round-tripped | roadmap post-1.0 (HW-gated) |
| USB audio interface | Not yet tested | roadmap post-1.0 (HW-gated) |

## In-flight

| Item | Target | Notes |
|------|--------|-------|
| Capture half of `vani_busy_open` on hardware | opportunistic | Needs an ACL on `pcmC1D0c` (`sudo setfacl -m u:$USER:rw /dev/snd/pcmC1D0c`). The playback half ran at 1.2.6; the capture direction is covered by the CPU suite only. |
| `O_CLOEXEC` on PCM / control descriptors | P2 | 1.2.6 audit L-2 — a forked-and-exec'd child inherits the fd and keeps the PCM busy. See roadmap. |
| Audible real-HW round-trip at 1.1.4 | opportunistic | `vani_devices` re-confirmed enumeration under yukti 2.3.8, but every PCM open on this box currently returns EACCES (logind ACL grants `sddm`, not this shell), so no tone was pushed at 1.1.4. The last audible confirmation is cyrius-doom 0.30.5 (2026-06-29). Re-run `./build/vani_tone` from inside a desktop audio session when convenient. |
| USB + HDMI real-HW round-trip | post-1.0 (HW-gated) | The v1.0 freeze criterion #1 residual. Same frozen code path as onboard HDA; verification needs USB-class / HDMI hardware access. Does **not** touch the frozen API. |
| ~~`snd_pcm_status` comment vs pinned table~~ | **done 1.2.0** | Buffer narrowed 192 → 152, `AlsaPcmStatusLayout` enum added, `load64` → `load32` on the u32 `state` field, and an assertion ties the ioctl's size bits to the constant. |
| XRUN-rate stress benchmark | optional post-1.0 | Reproducing CPU contention reliably needs harness setup beyond a release gate. |
| Portable `_clock_monotonic()` for throughput / latency_test | optional post-1.0 | `programs/throughput.cyr` / `latency_test.cyr` still use raw `syscall(228)` (x86_64-only by design); fixes when an aarch64 dev host with audio HW exists. |

## Downstream Consumers

> **No vendoring consumer has 1.2.6 yet.** doom, polyomino and bb
> carry vani 1.2.5 and mishran 1.2.2, so none has the busy-PCM open fix.
> They vendor `dist/vani-core.cyr` by copy, so picking it up is a
> deliberate re-vendor on their side, not something a vani release
> pushes. Verified at 1.2.6 on scratch copies: all four **build** with the
> 1.2.6 core swapped in, and polyomino (277), doom (376) and bb (253) pass
> their suites; mishran has no `.tcyr` files. Once polyomino re-vendors,
> its `audio_probe_playback` workaround can go.
>
> v1.0.0 froze the **full `vani_*` surface** under SemVer. The full
> ring/capture/playback/device/format surface is live-consumer
> validated by **dhvani**. The two remaining consumer-unvalidated
> corners are `vani_open_yukti` (the yukti adapter) and
> `src/mixer.cyr` (the hardware volume/mute control surface) — both
> internally test-covered (259 assertions) but not yet exercised by a
> live consumer.

| Project | Status | Notes |
|---------|--------|-------|
| **dhvani** | **live — FULL `vani_*` surface** | Released **2.2.4** (no vendored vani copy). `src/playback.cyr` bridges dhvani's f64 AudioBuffer ↔ vani's interleaved S16/S24/S32 PCM, exercising the full device path: `vani_open_playback` / `vani_open_capture`, `vani_ring_new` / `_write` / `_read`, `vani_play` / `vani_play_from_ring`, `vani_record` / `_record_to_ring`, `vani_configure`, `vani_format_new`, `vani_alsa_for`, `vani_start`, `vani_close`. References vani through functions only, so it DCE-prunes for vani-free consumers. **This is the consumer that unblocks the full-surface 1.0 freeze.** |
| cyrius-doom | **live + audibly verified on real HW** — core profile | Released **0.35.8** (tagged; vendors vani **1.2.5**). DOOM SFX route through `audio_write` in the 35 Hz `audio_tick` loop; audible at S16/stereo/44100 (2026-06-29). Deepest core exerciser: `audio_set_params_full` (period/buffer) + `audio_set_sw_params` + an `audio_open_capture` codec probe. Vendors `vendor/vani-core.cyr`. |
| cyrius-polyomino | **live** — core profile | Released **0.5.4** (tagged; vendors vani **1.2.5**). Piece-lock / line-clear / level-up / top-out SFX → `audio_write`. 6 `audio_*` symbols. |
| cyrius-bb | **live** — core profile | Released **0.8.3** (tagged; vendors vani **1.2.5**). Brick/wall/paddle + lost/over/fanfare SFX → `audio_write_bytes`. 6 `audio_*` symbols. |
| **mishran** | **live — core sink (real-HW verified; two-proc agnos claim RETRACTED)** | **0.5.7** (released; vendors vani **1.2.2**). The AGNOS software audio mixer / routing daemon (मिश्रण — "mixing"): fans many per-app S16 streams into one mixed writer to a vani sink. `MshRouter` opens/drives a real vani PCM device — `msh_router_open` (`audio_open_playback` → `audio_set_params` → `audio_prepare`), `msh_router_pump` → blocking `audio_write` (single-proc, `-EPIPE` recovery) **and** `msh_router_pump_nb` → `audio_avail`-gated `audio_write_nb` (multi-proc, cooperative), `msh_router_close` (drain + close). Vendors `vendor/vani-core.cyr` (provenance vani 1.2.2). `pump_probe` confirmed on real HW (2026-07-06). ⛔ **RETRACTED 2026-08-03** — this entry previously claimed a **two-proc tone** "proven non-silent on agnos QEMU (2026-07-10, RMS 2146)". **FALSE GREEN**: it required the `MISHRAN_DUPLEX_SELFTEST` kernel hook's `net_ip = 0x7F000001` assignment for the loopback connect to complete at all; hook + smoke deleted. mishran's own CHANGELOG retracts the same claim at its `[0.4.1]` entry. TCP-on-loopback is retired as the local transport; re-proof belongs on the agnos socket (`anu`) — agnos `docs/development/planning/ipc.md` §9-§10. The real-HW sink verification is untouched. |
| **jalwa** | **live — core `audio_*`, via dhvani** | Released **1.4.3**. Music player. Calls 7 core symbols (`audio_open_playback`, `audio_set_params`, `audio_prepare`, `audio_write`, `audio_drain`, `audio_drop`, `audio_close`) but declares no `[deps.vani]` — it reaches the shim through dhvani's bundle. Was listed here as "not yet integrated" through 1.2.2; corrected by the post-1.2.2 documentation sweep. |
| shravan / naad / shruti / agnoshi | not integrated | **No code in any of them calls vani.** naad feeds dhvani, which owns the hardware path; shravan is codec-only; shruti and agnoshi have no audio path yet. README listed all four as consumers until the post-1.2.2 sweep — they are the intended pipeline, not current callers. |

## Shipped Releases

| Tag | Date | Highlights |
|-----|------|------------|
| `1.2.7` | 2026-09-27 | **Patch — pin `6.6.2` → `6.6.6`, PE + agnos build repairs.** `_audio_open_pcm` gains a `CYRIUS_TARGET_WIN` refusal arm, so both bundles build for PE again (1.2.6 hit `SYS_FCNTL` / `O_NONBLOCK`, which the Windows peer lacks). All 20 ALSA ioctl sites route through a private `_audio_ioctl` that returns -ENOSYS on agnos, so the agnos build no longer borrows yukti ≤ 2.3.11's placeholder `SYS_IOCTL = 9001`. The aarch64 FIFO tests are an explicit, counted skip (cyrius ≥ 6.6.5 rewrites the literal `mknodat` #33 to `dup3`; 6.6.8 adds `sys_mknodat`). API unchanged (109 / 25). |
| `1.2.6` | 2026-09-27 | **Patch — a busy PCM no longer hangs the open.** `audio_open_*` open `O_NONBLOCK` (a busy PCM gives `-EBUSY` at once → null handle) and clear it with `F_SETFL` before the first PREPARE, so transfers still block: the kernel reads `O_NONBLOCK` for WRITEI / READI from a copy taken at PREPARE ([ADR 0005](../adr/0005-nonblocking-pcm-open.md), [architecture/001](../architecture/001-pcm-open-nonblock.md)). Reproduced and verified on the ALC897. The suite's exit status is now a real CI gate. New real-HW program `busy_open`; FIFO-based CPU tests with watchdogs. 893 → **909** assertions. API unchanged (109 / 25). Release audit: CVE window 2026-08-20 → 2026-09-27, UAPI re-pinned. |
| `1.2.5` | 2026-09-12 | **Patch — toolchain `6.6.0` → `6.6.2`.** No source change. No audit doc (covered by 1.2.6's). |
| `1.2.4` | 2026-09-07 | **Patch — pin `6.5.32` → `6.6.0`; `src/` on the Result value form.** `vani_result_unwrap` arity 1 → 2, API snapshot re-baselined for that signature. `vani_drain` / `vani_drop` / `vani_state` deliberately left mixed-return (the new diagnostic is advisory). No audit doc (covered by 1.2.6's). |
| `1.2.3` | 2026-09-07 | **cyrius 6.6.0 Result value form — BREAKING for `vani_result_unwrap`** (`(res)` → `(t, v)`). Err propagation re-wraps with `return Err(res);`. No audit doc (covered by 1.2.6's). |
| `1.2.2` | 2026-08-20 | **Patch — structural close-out of the P(-1) sweep.** Closes its largest open finding: XRUN/suspend/disconnect recovery had no coverage and no way to get any. The *decision* is now a pure function (`_vani_recovery_for`) tested exhaustively; a mockable ioctl indirection was considered and declined ([ADR 0004](../adr/0004-recovery-policy-seam.md)). Also: `snd_interval` open/empty flags were declared at v0.2.0 and read nowhere, so negotiate could return an endpoint the device excludes — now honoured; six mask sites made explicit about `FIRST_MASK`; dead `_clamp` removed; CI distlib gate extended to the `.deps` sidecars. 852 → **893** assertions, reference coverage **100%**. Mutation testing caught a tautological test in this release's own work. |
| `1.2.1` | 2026-08-20 | **Patch — closing half of the 1.2.0 P(-1) sweep.** Closes all seven code-level items 1.2.0 carried forward: idempotent close across all three close functions; `VANI_ERR_DISCONNECTED` wired end to end (kernel state 8 was missing, so an unplugged device was treated as a *recoverable* error by the retry logic); range guards on `_hwp_interval_set_exact` and `_hwp_mask_set_value`; `avail_min == 0` rejected up front; the `boundary`-is-an-output comment; and four comments still naming the deleted stdlib `audio.cyr` — a miss in 1.2.0's own doc sweep, which grepped for "5.8.0" rather than the filename. 778/778, API unchanged at 109/25. |
| `1.2.0` | 2026-08-20 | **Minor — full P(-1) sweep.** 13 repairs, all regression-tested with negative controls: the negotiated sample format never reached the kernel (U8→S8, S16_BE→S16_LE, FLOAT_LE→S32_LE); `audio_write_bytes` mis-sized S24_LE frames (stride 3 vs 4) so the kernel over-read past the caller's buffer; ring transfers leaked a scratch buffer per call (~110 MB / 60k iters, reproduced twice); `vani_play_from_ring` consumed the ring before writing so short writes destroyed audio; unbounded kernel counts in the mixer setters looped into a 1224-byte stack buffer; `vani_record_to_ring` trusted the kernel's frame count; 21 entry points faulted on a null handle (SIGSEGV reproduced). One **additive** public fn (`audio_set_params_fmt`) — hence a minor. 259 → **778** assertions, coverage 33% → **97%**. `_puti` deduplicated out of six programs onto stdlib `fmt_int`. cyrius pin `6.5.31`→`6.5.32`, provably inert. Method: 5 review lenses + adversarial re-verification that re-rated 50 of 55 findings. |
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
cyrius (6.6.2)
  └─ stdlib — syscalls / string / alloc / str / fmt / vec / io / fs /
             args / hashmap / tagged / fnptr / freelist / process /
             chrono / sakshi / yukti (2.3.10) / patra (1.14.1) /
             atomic / sync / thread_local
```

Those 21 declared leaves resolve to **40 modules** on disk (platform
variants: `alloc_agnos` / `_macos` / `_windows`, `args_*`, `fs_win`,
`process_*`, `sync_*`, `syscalls_*`, plus transitive `mmap` and
`result`).

No external (non-cyrius, non-AGNOS) git deps — vani is **all-stdlib** as
of 0.9.9. `patra` carries `target = "linux"` (yukti's `device_db`
backend is Linux-only; agnos gates it off).
