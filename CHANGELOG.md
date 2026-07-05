# Changelog

All notable changes to Vani will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.7] — 2026-07-04

### Added

- **AGNOS backend for the `audio_*` PCM shim** (`src/alsa.cyr`, the
  `[lib.core]` / `dist/vani-core.cyr` profile). Every seam function gains a
  `#ifdef CYRIUS_TARGET_AGNOS … #else … #endif` split (the sanctioned
  `cyrius/lib/net.cyr` per-function-branch shape): the Linux ALSA ioctl
  machinery becomes `#else`-only, and the agnos branch calls the sovereign
  `snd_*` syscall band (`#64-69`) directly — `audio_open_playback` →
  `sys_snd_open`, `audio_set_params(_full)` → `sys_snd_config` (format
  encoded `(bit_depth<<8)|channels`, e.g. `0x1002` = S16 stereo),
  `audio_write` → `sys_snd_write`, `audio_drain` → `sys_snd_drain`,
  `audio_close` → `sys_snd_close`. `prepare`/`start`/`drop`/`resume`/
  `set_sw_params` are agnos no-ops (the BDL ring self-paces); `open_capture`/
  `read` fail closed (no input band yet); `get_state` reports RUNNING. The
  handle struct is unchanged (fd/rate/channels/bit_depth); on agnos the "fd"
  slot is the `snd_id` (0..3). The full wrapper `vani_*` API flows through
  these, so **any vani-core consumer plays audio on agnos** — the same path
  `cyrius-doom` should consume instead of its hand-rolled `sys_snd_*` calls.
  `SYS_IOCTL` is undefined on agnos, so the Linux bodies **must** be fully
  `#else`-wrapped (not early-return) — hence every ioctl fn is branched.
- **`programs/vanitone.cyr`** — a Gate-4 bring-up proof: opens playback,
  configures 48k/16/2, blocking-streams a 1.5 s 440 Hz square (integer-only
  synthesis — no `f64`/SSE, so it runs on agnos ring-3 today), drains, closes.
  Built as a doom-style `dist/vani-core.cyr` consumer, it is **QEMU-validated
  on agnos** (`agnos/scripts/vani-tone-smoke.sh`: intel-hda wav capture,
  `RMS=2771 PEAK=4448`, `hda: output path enabled / stream running`).

### Changed

- **cyrius pin `6.3.5` → `6.4.2`** — for the `sys_snd_*` #64-69 peer (frozen
  audio ABI, cyrius 6.4.2) the agnos backend binds to, plus the
  `CYRIUS_TARGET_AGNOS` predefine that gates it.

### Notes

- The **full `vani_*` API does not yet build `--agnos`**: `src/device.cyr`
  pulls the **yukti** audio enumerator, which isn't agnos-ported (it uses
  `SYS_IOCTL` + wrong-arity `sys_stat`/`sys_mount`/`sys_rmdir` on agnos). The
  agnos-consumable path is therefore **`dist/vani-core.cyr`** (the `audio_*`
  shim, no yukti), exactly as `cyrius-doom` consumes it. A yukti agnos-port is
  the follow-on that unblocks the full multi-device API on agnos.

## [0.9.6] — 2026-06-29

### Changed

- **cyrius pin `6.2.1` → `6.3.5`** (ecosystem-wide stdlib pin sweep onto the
  current toolchain — matches patra `1.12.7`, which moved to the same pin).
  Clears the build-time pin-drift warning against the installed `cycc` 6.3.5.
- **`[deps.yukti]` `2.2.4` → `2.2.7`.** 2.2.7 namespaces yukti's error enum
  (`ERR_*` → `YUKTI_ERR_*`), which **clears the `ERR_TIMEOUT` duplicate-symbol
  collision** vani's build previously emitted (old yukti `ERR_TIMEOUT = 9` vs.
  stdlib sakshi `ERR_TIMEOUT = 5`, conflicting values). vani calls only
  `yukti_audio_*`, so the breaking rename is non-breaking here — verified zero
  bare yukti `ERR_*` references in `src/`, `programs/`, `tests/` (the two
  `ERR_YUKTI_DESCRIPTOR` hits are assert message strings; the real symbol is
  vani's own `VANI_ERR_YUKTI_DESCRIPTOR`).
- **`[deps.patra]` `1.9.5` → `1.12.7`.** Source-compatible for vani: the 9
  `patra_*` symbols yukti's device_db references have byte-identical signatures
  across 1.9.5 → 1.12.7, and vani never exercises the device_db path (only the
  `yukti_audio_*` enumerator). patra's internal `TK_*` → `SQLT_*` rename and
  `.patra` on-disk format change (1.10–1.12) are confined to patra internals.
- **Added `chrono` to `[deps].stdlib` and the `src/lib.cyr` include chain
  (before `yukti`).** Load-bearing for this bump: yukti ≥ 2.2.6 routes its
  device_db timestamps through `chrono.clock_epoch_secs()`, and cyrius **6.3.2
  promoted a reachable call to an undefined function from a warning to a hard
  compile error**. Without `chrono`, the yukti bump would fail the build
  outright. vani's own `src/*.cyr` call no chrono symbols — the dependency is
  purely transitive via yukti.
- **Restored unconditional `cyrius deps --verify` in CI and release.** The
  Cyrius 6.0.1 lockfile-truncation workaround — skip hash verification when
  `cyrius.lock` is empty (`ci.yml`, `release.yml`) and drop the empty lock from
  release assets (`release.yml` "Drop empty cyrius.lock" step) — is removed now
  that the 6.3.5 toolchain writes a full lock. Reproduced the original failure
  condition under 6.3.5: `cyrius deps` locks 40 deps (3,656 B, not 0) and
  `cyrius deps --verify` reports 40 verified / 0 failed. Supply-chain hash
  integrity is enforced again on every CI and release run.

### Verified

- `cyrius deps`: 40 deps locked (lockfile 3,656 B, healthy); `cyrius deps
  --verify`: **40 verified, 0 failed** (workaround removed — see Changed).
- `cyrius build programs/smoke.cyr` (DCE): **0 warnings**, 489,520 B x86_64 ELF.
  The pin-drift, `ERR_TIMEOUT`-collision, and `clock_epoch_secs`-undefined
  warnings are all gone. Binary grew vs. 0.9.4 (457,296 B) from yukti 2.2.7's
  device_db surface + the new `chrono` module.
- Aarch64 cross-build (`cycc_aarch64`, DCE): clean, valid ARM aarch64 ELF.
- `cyrius lint`: 0 warnings across `src/`, `programs/`, `tests/`.
- `cyrius fmt`: diff-clean.
- `cyrius vet programs/smoke.cyr`: 1 dep, 0 untrusted, 0 missing.
- `cyrius test tests/tcyr/vani.tcyr`: **258 / 258** pass.
- `cyrius bench tests/bcyr/vani.bcyr`: no regression — `ring_200ms_playback`
  86.4 µs avg (min 82.4 µs) vs. 82.96 µs baseline at `59dd681`, within the
  noise floor. **bench-history.csv not appended** (quiet pin bump, matches the
  0.9.5 precedent). Note: cyrius 6.3.5's bench CSV emitter inflates
  µs-formatted values 10× (`CSV:ring_200ms_playback,823525` vs. the correct
  86.4 µs human reading) — the raw CSV row must not be committed as-is.
- `cyrius distlib` + `cyrius distlib core`: `dist/vani.cyr` (2100 lines) +
  `dist/vani-core.cyr` (799 lines) regenerated with v0.9.6 headers; bundle
  bodies byte-identical (vani's distlib'd modules carry no includes). cyrius
  6.3.5 also emits `dist/vani.deps` / `dist/vani-core.deps` stdlib-leaf
  sidecars (now committed, matching patra's convention).

### Security

- CVE awareness sweep since the 2026-05-01 audit (no new audit doc — quiet pin
  bump). Reviewed ALSA kernel CVEs: snd-aloop UAF `CVE-2026-46090`, OSS-compat
  `CVE-2026-46157`, USB UAC3 parser `CVE-2026-46146`, control-enum
  `CVE-2026-46088`, caiaq USB `CVE-2026-46004`/`CVE-2026-46048`, HDA Conexant
  `CVE-2026-53291`. **All are kernel-side; none are reachable** from vani's
  pure-userspace native-PCM ioctl surface (vani issues `SNDRV_PCM_IOCTL_*` /
  control ioctls, parses no USB descriptors, registers no controls). Closest
  touch is `src/mixer.cyr` (control reads, gated by element type) vs.
  `CVE-2026-46088` — awareness-only, no guard warranted. No vani change.

## [0.9.5] — 2026-06-12

### Changed

- **cyrius pin `6.0.1` → `6.2.1`** (ecosystem-wide stdlib pin sweep onto the
  current toolchain). No source changes — vani's `[deps]` carries no carved-out
  modules and its external deps (yukti, patra) are unaffected. Verified green on
  6.2.1: `cyrius deps` resolves cleanly, full `.tcyr` suite 258/258, bench 1/1,
  `dist/vani.cyr` + `dist/vani-core.cyr` regenerated via `cyrius distlib`.

## [0.9.4] — 2026-05-21

### Changed

- `cyrius` pin bumped 5.11.4 → 6.0.1.
- `[deps.yukti]` pin bumped 2.2.2 → 2.2.4.
- `[deps.patra]` pin bumped 1.9.3 → 1.9.5.
- CI / release workflows: `cc5_aarch64` → `cycc_aarch64` (named
  compiler renamed in Cyrius 6.0). Same pattern agnosys carries.
  Cyrius 6.0.1 tarball ships only `cycc_aarch64`; the old name
  would have hard-failed the aarch64 cross-build step.
- CI / release `cyrius deps --verify` made conditional on a
  non-empty `cyrius.lock` (Cyrius 6.0.1 deps bug: `cyrius deps`
  reports "N deps resolved" but truncates the lockfile to 0 bytes,
  then `--verify` bails with "no cyrius.lock found"). Pattern
  matches agnosys / patra workaround. Restore unconditional verify
  once cu fix lands.

### Verified

- `cyrius lint`: 0 warnings.
- `cyrius fmt`: diff-clean across `src/`, `programs/`, `tests/`.
- `cyrius vet programs/smoke.cyr`: 1 dep, 0 untrusted, 0 missing.
- `cyrius build programs/smoke.cyr` (DCE): 457,296 B x86_64 ELF.
- Aarch64 cross-build (`cycc_aarch64`): clean.
- `cyrius test tests/tcyr/vani.tcyr`: 258 / 258 pass.
- `cyrius bench tests/bcyr/vani.bcyr`: appended row to
  `bench-history.csv` (commit `59dd681`). No regression vs. prior
  baselines (e.g. `ring_200ms_playback` 82,958 ns vs. 80,616 ns at
  `f884617` — within noise floor).
- `cyrius distlib` + `cyrius distlib core`: `dist/vani.cyr` 2072
  lines, `dist/vani-core.cyr` 791 lines (v0.9.4 headers).

## [0.9.3] — 2026-05-11

### Changed

- **Stdlib annotation pass**: every public fn in `src/*.cyr`
  carries a `: i64` return-type annotation. Same shape as
  cyrius's own v5.11.x annotation arc (Phases 1-6 in
  cyrius/CHANGELOG.md). Annotations are parse-only — zero
  runtime / codegen change.
- `cyrius` pin bumped 5.8.64 → 5.11.4 — required because
  the annotation syntax (`: i64` return types) needs the
  v5.10.x REAL TYPE SYSTEM arc.
- `dist/vani.cyr` regenerated via `cyrius distlib` (2072 lines
  at v0.9.3). Ready for the next cyrius-side fold-in slot.

### Verified

- `cyrius build programs/smoke.cyr build/vani_smoke`: green.
- Dead-code report unchanged (annotations don't alter call graph).

## [0.9.2] — 2026-05-05

### Changed

- `cyrius` pin bumped 5.7.48 → 5.8.64 ahead of the cyrius v5.8.65
  stdlib foldin. Vani is on the foldin manifest; this patch is
  the prerequisite for cyrius's `[deps].vani.tag` to point at
  0.9.2 in the foldin slot.
- `[deps.yukti].tag` bumped 2.2.1 → 2.2.2 (latest);
  `[deps.patra].tag` bumped 1.9.2 → 1.9.3 (latest). Aligns vani
  with the cyrius-side pin set heading into the foldin.
- No source changes — pure pin + version bump.

### Verified

- `cyrius test`: **258 / 258** asserts pass against cyrius 5.8.64
  with yukti 2.2.2 + patra 1.9.3 resolved.
- `cyrius fmt --check`: clean across all source.

## [0.9.1] — 2026-05-01

Audio-core distribution profile. Driven by cyrius-doom's
"6-of-106-symbols" usage report — proposal at
[cyrius-doom/docs/proposals/vani-audio-core-profile.md](https://github.com/MacCracken/cyrius-doom/blob/main/docs/proposals/vani-audio-core-profile.md).
Bumping cyrius-doom from vani 0.3.0 → 0.9.0 grew its binary by
+340 KB (259,920 → 600,608 B) for a 117-line audio module that
calls 6 vani symbols. The `core` profile gives playback-only
consumers a much smaller bundle without changing the full bundle
or the API surface.

### Added

- **`[lib.core]` distribution profile** in `cyrius.cyml`. Single
  module: `src/alsa.cyr`. Same `cyrius distlib` invocation pattern
  yukti uses for its `dist/yukti-core.cyr`. Generated via
  `cyrius distlib core` → `dist/vani-core.cyr`.
- **`dist/vani-core.cyr`** — 29,015 bytes (vs 76,124 for the full
  bundle, **62% smaller**). 22 public `audio_*` symbols covering
  the entire PCM playback / capture path (open / set_params /
  prepare / start / write / read / drain / drop / state / resume /
  query_caps / can_set_params / close + 4 getters). Strict subset
  of the full surface — no SemVer risk, additive only.
  `src/alsa.cyr` is intentionally self-contained (zero
  cross-module references in its source) so the bundle is a
  single-file standalone consumable.
- **`docs/api-surface.core.snapshot`** — 22 public symbols, sorted,
  same `module::name/arity` format as the full snapshot. Captured
  as the v1.0.0 freeze baseline for the core profile.
- **CI dual-bundle gate**: `.github/workflows/ci.yml`'s "Verify
  dist bundles" step now regenerates both `dist/vani.cyr` and
  `dist/vani-core.cyr` and fails on either's drift.
- **Release dual-artifact**: `.github/workflows/release.yml` ships
  both `vani-X.Y.Z.cyr` and `vani-X.Y.Z-core.cyr` alongside the
  smoke ELFs and SHA256SUMS.

### Changed

- Consumer `[deps.vani]` blocks can now opt into the core profile
  by changing one line in their manifest:
  ```toml
  [deps.vani]
  git = "https://github.com/MacCracken/vani.git"
  tag = "0.9.1"
  modules = ["dist/vani-core.cyr"]   # ← was "dist/vani.cyr"
  ```
  Drop-in for any consumer that only calls the `audio_*` shim.
  Source code in the consumer doesn't change because the
  `audio_*` ABI is byte-identical between profiles.

### Verified

- `cyrius distlib` + `cyrius distlib core` both regenerate
  diff-clean against the v0.9.1 header.
- 258/258 tests pass; 13/13 benches within noise of the 0.9.0
  baseline (no source changes in `src/` — only manifest +
  tooling additions).
- Both x86_64 and aarch64 cross-builds clean against the full
  profile.
- Core profile bundle parses standalone (`note: bundle has
  unresolved symbols (expected for consumer-included bundles;
  stdlib is supplied by the consumer's `[deps] stdlib` list)`).
  No transitive pulls from `src/error.cyr` or `src/format.cyr`
  needed — answering the proposal's open question #4.

### References

- ADR forthcoming if a third such profile or override pattern
  lands; today both profile-mechanism and the yukti/patra
  git overrides share the "fast-moving sibling dep" shape
  documented in `docs/adr/0001-yukti-git-override.md`.

## [0.9.0] — 2026-04-30

Pre-1.0 release candidate. Closes the in-vani v1.0.0 work; the
remaining v1.0.0 freeze criteria (#1 multi-hardware coverage, #2
cyrius-doom integration tag, #3 second consumer, #4 API surface
diff captured at freeze, #5/#6 freeze-time docs) are now external
or release-time concerns.

### Added

- **aarch64 cross-build unblocked.** Migrated all `src/*.cyr`,
  `programs/*.cyr`, `tests/tcyr/*.tcyr`, `tests/bcyr/*.bcyr` raw
  syscall sites (73 total) to the stdlib's arch-translating
  wrappers: `syscall(1, ...)` → `sys_write(...)` (35 sites);
  `syscall(2, ...)` → `sys_open(...)` (3); `syscall(3, ...)` →
  `sys_close(...)` (2); `syscall(16, ...)` → `syscall(SYS_IOCTL,
  ...)` (20 — no stdlib wrapper, but the constant is arch-correct
  on both peers); `syscall(60, ...)` → `sys_exit(...)` (11). The
  two `syscall(228, ...)` (`clock_gettime`) sites in
  `programs/throughput.cyr` and `programs/latency_test.cyr` stay
  raw — those are real-HW measurement programs that only ever
  build on x86_64. Same playbook yukti's 2.1.3 cut used.
- **CI cross-build gate**: `.github/workflows/ci.yml` re-enables
  the `Cross-build aarch64` step (was deferred at 0.3.0). The
  release workflow ships `vani-X.Y.Z-smoke-aarch64-linux` ELF
  alongside the x86_64 smoke binary and SHA256SUMS.
- **API surface snapshot** at `docs/api-surface.snapshot` (106
  public symbols across `src/alsa.cyr`, `src/buffer.cyr`,
  `src/capture.cyr`, `src/device.cyr`, `src/error.cyr`,
  `src/format.cyr`, `src/mixer.cyr`, `src/playback.cyr`).
  Captures the v0.9.0 baseline that v1.0.0's freeze will diff
  against. Format mirrors `cyrius api-surface` ("module::name/arity"
  per line, sorted, public = `fn NAME(...)` not prefixed with `_`).

### Changed

- `[deps]` block adds `[deps.patra]` git override at tag `1.9.2`
  for aarch64 portability. Cyrius 5.7.48 bundles patra 1.9.0,
  which uses raw `SYS_OPEN` (undefined on aarch64's generic
  syscall table — that table only exposes `SYS_OPENAT`). 1.9.2
  migrated to stdlib `sys_open` wrappers. Removed `patra` from
  the `stdlib = [...]` list to avoid double-resolution. Drop
  the override once cyrius re-bundles patra ≥ 1.9.2 — same
  trigger shape as the existing yukti override.

### Verified

- **Second P(-1) scaffold-hardening sweep** for v0.9.0 (audit
  `docs/audit/2026-04-30-v0.9.0-audit.md`). Cleanliness gates,
  test sweep (258/258), distlib diff-clean against the new
  v0.9.0 header, bench baseline within noise of the 0.3.0
  baseline (no syscall-wrapper overhead — calls inline or
  DCE-strip). aarch64 cross-build now produces a valid ARM
  ELF; verified locally before re-enabling CI.
- All 6 silent real-HW programs (`probe`, `caps`, `throughput`,
  `mixer_test`, `latency_test`, `devices`) PASS on the dev box
  (HDA Generic, 8 PCM endpoints) after the syscall migration —
  no behavioral regression.

## [0.3.0] — 2026-04-30

First public release. Foundation, full HW_PARAMS / SW_PARAMS,
mixer scaffold, latency presets, real-HW verification on onboard
HDA Generic, and yukti integration all roll up into this cut —
the v0.1.0 / v0.2.0 / v0.3.0 milestones from the development
roadmap were never tagged individually, so 0.3.0 ships them
together as the first release on record.

### Verified

- **Second P(-1) scaffold-hardening sweep** for the v0.3.0 cut
  (audit `docs/audit/2026-04-30-v0.3.0-audit.md`). One LOW
  finding (CI lacked defense-in-depth lock-file presence guard)
  fixed in this sweep with a new "Lock file present" step in
  `.github/workflows/ci.yml`. No HIGH / MED findings. CVE window
  unchanged from prior sweep (same date, hours apart). Bench
  baseline within noise of prior commit `e031c0d` — minor
  improvements from the cyrius 5.7.40 → 5.7.48 toolchain bump.
- **Cleanliness pass** as P(-1) prerequisite: renamed
  `test_ioctl_type_is_A` → `_is_a` and `test_ctl_ioctl_type_is_U`
  → `_is_u` (cyrlint snake_case rule); `cyrius fmt` rewrites on
  `src/alsa.cyr`, `src/device.cyr`, `src/mixer.cyr`,
  `programs/latency_test.cyr`, `tests/tcyr/vani.tcyr`,
  `tests/bcyr/vani.bcyr`; `dist/vani.cyr` regenerated.
- **GitHub Actions CI/release pipeline** mirroring yukti's
  three-job CI (build/security/docs) and tag-driven release
  flow. Vani-specific deltas: vet runs on `programs/smoke.cyr`
  (no CLI binary), single `dist/vani.cyr` drift check (no
  `-core` profile), no kernel-safe tripwire / fuzz steps,
  aarch64 cross-build deferred with comment pointer to the
  v0.4.x roadmap section. Smoke ELF shipped as
  `vani-X.Y.Z-smoke-x86_64-linux` so consumers can sanity-check
  the toolchain produced a working artifact.

### Added

- **v0.3.0 yukti integration** — `vani_open_yukti(desc)` is now a
  thin adapter from a yukti `AudioDeviceInfo` descriptor to a
  `VaniDevice` handle. yukti owns device identity end-to-end (card,
  device, direction, hw_id); vani's only job is "open this endpoint
  and wrap it." Direction is read off the descriptor — passing it
  separately would be redundant and create a typo surface where the
  explicit value disagrees with the descriptor's. The yukti
  `AudioDirection` enum is bit-for-bit identical to vani's
  `VaniDirection`, so the value passes through to the wrap helper
  without translation. Pinned by `test_yukti_direction_matches_vani_direction`
  (1:1 invariant) and `test_open_yukti_descriptor_accessor_projection`
  (`AudioInfoOff` field offsets) — both break loudly if yukti
  reshuffles the descriptor in a way that would silently mis-route.
- `programs/devices.cyr` — yukti-driven enumeration tour: lists
  every PCM endpoint via `yukti_audio_devices()` and runs the
  `programs/probe.cyr` open → state → configure → state → prepare
  → state → close sequence against the first playback descriptor
  routed through `vani_open_yukti`. **PASS on dev box** (8 PCM
  endpoints across cards 0/1/2 — HDA analog + HDMI + ACP capture;
  first playback is card 1 device 0 / `pci:0000:04:00.6:dev0:p`).
- Convenience use of yukti's filter API: consumers wanting playback-
  only or capture-only enumeration use `yukti_audio_devices_for_direction(YUKTI_AUDIO_PLAYBACK)`
  directly — yukti is in vani's stdlib include chain so no extra
  import is needed, and a vani-side wrapper would just be a name
  alias.

### Changed

- **Toolchain**: cyrius pin bumped 5.7.39 → 5.7.48.
- **Dependency wiring**: yukti moved from the cyrius stdlib bundle
  to a `[deps.yukti]` git override pinned at tag `2.2.1` (cyrius
  5.7.48 still ships yukti 2.1.1 in its bundled `lib/`). The
  override comment in `cyrius.cyml` notes this should be removed
  once cyrius re-bundles yukti ≥ 2.2.1. The 2.2.1 surface adds
  `yukti_audio_devices` + nine accessors plus the
  `_for_direction` / `_for_card` filters and `audio_devices`
  device_db table that v0.3.0 relies on.
- `src/lib.cyr` now includes `lib/fs.cyr` — yukti's audio
  enumerator uses `dir_list` to walk `/dev/snd`.
- **Breaking** (pre-1.0): `vani_open_yukti` signature changed from
  `(desc, direction)` → `(desc)`. The previous form was a stub
  returning a "pending — see roadmap v0.3.0" error in every code
  path; no real consumers existed.

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

- **#8 — bench harness**: done.
  - `tests/bcyr/vani.bcyr` — 13 CPU-only benches covering format
    math (`bytes_per_frame`, `frames_to_bytes`, `ms_to_frames`,
    `alsa_for`), ring buffer (`ring_used`, `ring_write_64b`,
    `ring_read_64b`, `ring_200ms_playback`), HW_PARAMS struct
    manipulation (`hwp_init_any`, `hwp_mask_set_value`,
    `hwp_interval_set_exact`, `hwp_mask_has_bit`), and
    negotiation (`negotiate_format_pick`).
  - `bench-history.csv` — baseline numbers as of e031c0d.
    Schema matches mabda: `timestamp,commit,branch,benchmark,
    estimate_ns`. Each `cyrius bench tests/bcyr/vani.bcyr`
    emits a `CSV:` line per bench for easy appending.
  - Hot-path numbers (min ns): `alsa_for` 3, `ms_to_frames` 5,
    `ring_used` 7, `hwp_mask_has_bit` 8, `negotiate_format_pick`
    11, `ring_write_64b` 170, `ring_read_64b` 311,
    `hwp_init_any` 924, `ring_200ms_playback` 83451.

- **#9 — throughput / xrun (partial)**: throughput done.
  `programs/throughput.cyr` plays 200 ms of silence and reports
  frames-actually-written, vani_play wall time, drain wall time,
  effective fps, and final xrun count. Real-HW PASS on
  `pcmC1D0p`: 9600/9600 frames, 178746162 ns play wall,
  200111747 ns total (≈ realtime), 0 xruns. Latency-from-
  write-to-audible (needs external loopback) and xrun-rate-
  under-load deferred to v0.4.0 alongside configurable period
  / buffer sizes.

### v0.3.0 progress (in-flight)

- **#2 — `snd_ctl_elem_id` packing**: done.
  `_ctl_elem_id_init(eid, iface, name)` builds the 64-byte ID
  with bounded name length (43 chars + null) and the right iface
  enum. Plus `_ctl_elem_id_get_name` for read-back.
- **#3 — `snd_ctl_elem_value` packing**: done.
  Layout enums for `snd_ctl_elem_id` (64 B), `snd_ctl_elem_info`
  (272 B), `snd_ctl_elem_value` (1224 B), and
  `snd_ctl_elem_list` (80 B = 74 raw + 6 alignment padding).
  All four pinned by tests.
- **#4 — `vani_mixer_set_volume`**: done. Resolves percent
  0..100 to the device's native [min, max] range via
  ELEM_INFO, then writes via ELEM_WRITE for every channel
  (count comes from info).
- **#5 — `vani_mixer_set_mute`**: done. BOOLEAN-typed elements,
  human-direction muted (1 = silenced) translates to ALSA's
  switch convention (0 = muted, 1 = on flow).
- **#6 — `vani_mixer_list_elements`**: done. Two-pass
  ELEM_LIST: first call returns count, second fills the
  `snd_ctl_elem_id` array. Returns a 24-byte list-handle struct
  with `count`, `pids`, `capacity`. Helpers
  `vani_mixer_list_count`, `vani_mixer_list_id_at`,
  `vani_mixer_list_name`.
- **#7 — `vani_mixer_get_volume` / `vani_mixer_get_mute`**:
  done. Mirror of the setters; returns Result<percent>
  (or Result<0|1> for mute).
- `programs/mixer_test.cyr` — read-only enumeration probe.
  Lists every element, queries volume + mute for every INT /
  BOOL control, prints type + range + current value. Real-HW
  PASS on card 1: 38 elements enumerated cleanly (Front /
  Surround / Center / LFE / Headphone / Master / Capture /
  Mic Boost / etc.); jack-detect and channel-map controls
  surface as "info FAIL" — they have non-INT/BOOL types and
  fall outside v0.3.0's scope (lands later when needed).
- Test suite gains a `mixer` group: 10 test fns / 47
  assertions covering struct sizes, field offsets, ioctl
  size+type encoding, iface + elem type enums, name init +
  truncation. Total 162 → 209 assertions.

### v0.4.0 progress (in-flight)

- **#5 — typed `VaniState` enum**: done. `VaniState` mirrors
  `AlsaPcmState` 1:1 (OPEN, SETUP, PREPARED, RUNNING, XRUN,
  DRAINING, PAUSED, SUSPENDED) plus a `VANI_STATE_UNKNOWN`
  sentinel for kernel-returned negatives or out-of-range values.
  Helpers `vani_state_name`, `vani_state_from_raw`,
  `vani_state_typed`. `programs/probe.cyr` and
  `programs/latency_test.cyr` use the typed form.
- **#3 — `SNDRV_PCM_IOCTL_SW_PARAMS` (136 bytes)**: done.
  `AlsaSwParamsLayout` enum pins all 13 field offsets.
  `audio_set_sw_params(dev, start_threshold, stop_threshold,
  avail_min)` packs the struct with sane defaults (period_step=1,
  xfer_align=1, silence=0, boundary=AUDIO_FRAMES_MAX). Higher
  level `vani_set_sw_params` available on the device handle.
- **#2 — configurable period / buffer**: done.
  `audio_set_params_full(..., period_frames, buffer_frames)`
  accepts non-zero values to constrain via
  `SNDRV_PCM_HW_PARAM_PERIOD_SIZE` / `BUFFER_SIZE`; passing 0
  leaves them "any". `audio_set_params` is now a thin wrapper.
  `vani_configure_buffered` exposed at the device layer.
  `_vani_round_period` rounds up to multiples of 16 to dodge
  HDA / USB grain quirks.
- **#4 — suspend / resume**: done. `SNDRV_PCM_IOCTL_RESUME =
  0x00004147` added. `audio_resume(dev)` issues the ioctl;
  returns -ENOSYS on kernels that don't implement it for the
  driver. `vani_resume` falls back to `audio_prepare` in that
  case. `vani_play` / `vani_record` recovery paths now handle
  `SND_PCM_STATE_SUSPENDED` (try resume, retry the I/O once).
- **#6 — low-latency preset**: done.
  `vani_configure_low_latency(d, fmt)` — 10 ms × 4 = 40 ms
  buffer, start_threshold=1 (start ASAP), stop_threshold=
  buffer, avail_min=period. Sub-10 ms is rejected by HDA Generic
  (kernel-side BDL alignment) — pro-audio consumers needing
  ultra-low latency on dedicated USB DACs should call
  `vani_configure_buffered` directly with their interface's
  values. Real-HW PASS on `pcmC1D0p`: 9600/9600 frames, 0 xruns.
- **#7 — casual preset**: done.
  `vani_configure_casual(d, fmt)` — 16 ms × 4 = 64 ms,
  start_threshold = 2 periods (kernel head start),
  stop_threshold = buffer, avail_min = period. Real-HW PASS:
  9600/9600 frames, 0 xruns.
- `programs/latency_test.cyr` — runs both presets back-to-back,
  prints state transitions, write/drain wall time, xrun count.
  Real-HW PASS for both presets.
- Test suite gains a `v0.4.0 state + sw_params` group: 7 test
  fns / 40 assertions covering VaniState mapping, ALSA enum
  equality, raw-int classification, SW_PARAMS struct layout,
  and the RESUME / SW_PARAMS ioctl encodings. Total
  209 → 249 assertions.

### Fixed (in-flight, v0.3.0)

- **POST-AUDIT-2 (HIGH)** — `SNDRV_CTL_IOCTL_ELEM_LIST` had
  `size=280` baked in, but `sizeof(struct snd_ctl_elem_list)`
  is 80 on x86_64 (74 raw bytes + 6 padding for the embedded
  pointer's 8-byte alignment). Same shape as POST-AUDIT-1
  (the WRITEI/READI bug): kernel ioctl dispatcher matches
  the full command number, falls through to `-ENOTTY` when
  the size bits are wrong. Surfaced when `vani_mixer_list_elements`
  was first exercised on real hardware. Fixed:
  `0xC1185510 → 0xC0505510`. Pinned by
  `test_ctl_ioctl_size_encoding` against all 5 ctl ioctls.

### Fixed (post-audit, v0.2.0)

- **POST-AUDIT-1 (HIGH)** — `SNDRV_PCM_IOCTL_WRITEI_FRAMES` and
  `READI_FRAMES` had `size=16` baked into the ioctl number, but
  `struct snd_xferi` is 24 bytes on 64-bit Linux (`result + buf +
  frames`). Kernel dispatcher matched neither case and fell
  through to `-ENOTTY (-25)`, breaking every PCM write/read.
  Carried from upstream `cyrius/lib/audio.cyr`; never noticed
  there because no consumer exercised the path. Fix bumps both
  constants by 0x80000 (size shift), grows `var xferi[16]` to
  `var xferi[24]`, repositions buf/frames to +8/+16, and reads
  the kernel-written `result` field at +0 for the return value.
  Pinned by new tests `test_ioctl_size_encoding_matches_struct_size`
  and `test_ioctl_type_is_A` (16 assertions). Filed in the audit
  doc under "Post-audit findings". Total suite 146 → 162
  assertions.

### Architecture

- vani is now the single audio authority in stdlib (mirrors mabda
  for GPU, yukti for device discovery). Raw ALSA ioctls + typed
  errors + ring buffer + XRUN recovery + mixer all ship from one
  `dist/vani.cyr` bundle.
- `audio` removed from `[deps].stdlib` — vani owns that surface in
  `src/alsa.cyr`.
- yukti and sakshi are stdlib deps (no longer external git pins).
- `lib/` is now a build artifact (gitignored), populated by `cyrius deps`.
