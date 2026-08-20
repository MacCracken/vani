# Changelog

All notable changes to Vani will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed — documentation sweep

Docs only; no source, no API, no behaviour change.

- **`cyrius.cyml` is a manifest again, not a ledger.** Its comment blocks had
  accumulated provenance and history — where `alsa.cyr` was lifted from, which
  proposal drove the core profile, what would happen "once cyrius bundles it"
  (it has, since 6.4.3). Trimmed to what each block *is* plus a pointer to
  `docs/architecture/overview.md`, and the sections it now points at were
  written to actually cover it: distribution profiles, and why the pin — not
  `./lib/` — is the supply chain.

- **`README.md` — the consumer table was wrong in both directions.** It listed
  shravan, naad, shruti and agnoshi as consumers; **none of them calls vani**.
  It omitted mishran, cyrius-polyomino and cyrius-bb, which do. jalwa is live
  too, reaching the `audio_*` shim through dhvani's bundle rather than a direct
  dependency. Now split into live consumers (with profile and what each
  exercises) and the intended-but-not-yet-integrated pipeline.

  Also corrected there: the layered model referenced `stdlib audio.cyr`, which
  no longer exists, and `audio_set_params` where the format-preserving
  `audio_set_params_fmt` is now the configure path; the pipeline diagram had
  encode feeding vani, which contradicts PCM-only; and the hardware table read
  as a support matrix when only onboard analog has ever been *run*.

- **`docs/architecture/overview.md` — three stale sections.** The XRUN table
  claimed SUSPENDED is surfaced because "resume needs explicit consent", long
  after the code started resuming, and had no DISCONNECTED row at all. The
  mixer section described per-element struct packing as future work "landing in
  v0.3.0". `vani_open_yukti` was shown with its pre-0.3.0 two-argument
  signature. All corrected, and the recovery table now names the
  `VANI_RECOVERY_*` constants it maps to.

- **`docs/development/roadmap.md` restructured.** Its own header says
  "forward-looking only — don't duplicate CHANGELOG", and it had grown five
  completed-work sections doing exactly that. Those collapse to a pointer;
  ~290 lines → 179. Open items are now P1 / P2 / Hardware coverage /
  Unscheduled / Declined, with the real-hardware gap stated as the largest open
  item rather than buried in a v0.5.x heading.

- **`docs/development/state.md`** — every consumer version was behind (dhvani
  2.1.2→2.2.1, doom 0.30.5→0.35.4, polyomino 0.5.1→0.5.2, bb 0.8.0→0.8.1,
  mishran 0.4.1→0.5.4), jalwa was still filed as "not yet integrated", and the
  four non-consumers were not identified as such. Added an explicit note that
  **every vendoring consumer is behind** — doom on 1.1.2, mishran on 1.1.0,
  polyomino and bb on 0.9.9 — so none of them has the 1.2.x fixes, and picking
  them up is a deliberate re-vendor on their side.

- **P(-1) checklist item 3** now says both bundles *and* both `.deps` sidecars
  must regenerate diff-clean, matching the gate 1.2.2 actually extended.

## [1.2.2] — 2026-08-20

Closes the structural items the 1.2.0 P(-1) sweep left open — the ones that needed a
design decision rather than an edit. No API change (109 / 25), pin unchanged at 6.5.32.

### Added

- **A testability seam for the recovery paths, and an ADR explaining the shape of it.**
  The sweep's largest open finding was that XRUN recovery, suspend/resume and the
  disconnect path had no coverage and no way to get any — reaching them needs a kernel
  that returns `-EPIPE` / `-ESTRPIPE` on demand. Two of 1.2.0's defects lived exactly
  there.

  The decision "a transfer failed — what now?" is now a pure function,
  `_vani_recovery_for(xfer_result, state)` in `src/error.cyr`, and both `vani_play` and
  `vani_record` classify through it before acting. The classification is tested
  exhaustively: every kernel state including ones vani has never seen, `-1` for a failed
  `STATUS` ioctl, and every action.

  **A mockable ioctl indirection was considered and declined** — it would put an indirect
  call on the transfer path and a DCE-defeating global in code that four consumers vendor
  into games, to test a path none of them can trigger differently. Reasoning, and the
  residue it leaves untested, are in
  [ADR 0004](docs/adr/0004-recovery-policy-seam.md).

### Fixed

- **`snd_interval` open/empty flags were declared and never read** (`src/alsa.cyr`).
  `AlsaIntervalFlag` has existed since v0.2.0; nothing consulted it, so every interval was
  treated as the closed range `[min, max]`. ALSA uses `openmin` / `openmax` to mean the
  endpoint is *excluded*, so `vani_format_negotiate` could clamp a request onto a rate or
  channel count the device had just told us it does not accept — returning `Ok` for a
  format `HW_PARAMS` then rejects.

  New `_hwp_interval_flags` / `_hwp_interval_lo` / `_hwp_interval_hi` /
  `_hwp_interval_is_empty` / `_hwp_interval_clamp` honour all three flags, and
  `_hwp_interval_contains` (previously kept alive only by its own test) now does too. An
  empty or inverted interval yields −1 — "this device cannot do it" — rather than a
  bogus pick, and `vani_format_negotiate` surfaces that as a named error.

- **Six mask call sites relied implicitly on `FIRST_MASK == 0`**, asymmetric with the
  twelve interval sites that subtract `FIRST_INTERVAL` explicitly. Now symmetric. Costs
  nothing: same unreachable-fn count, same NOPed bytes, same `R+E` segment size — the
  emitted code is the same size, laid out differently. It buys real robustness a test
  cannot: were `FIRST_MASK` ever renumbered, the subtraction adapts while an assertion on
  the slot values would still pass.

- **`_clamp` removed** — dead in production once negotiation moved to
  `_hwp_interval_clamp`, and referenced only by its own test.

- **CI's distlib drift gate now covers the `.deps` sidecars**, not just the two `.cyr`
  bundles. The sidecars are what a consumer's `cyrius deps` reads, so a stale one breaks
  downstream builds while both bundles look fine. Self-healing in practice; "in practice"
  is not a gate. Verified to fire on a tampered sidecar.

### Added — tests

**852 → 893 assertions**, and reference coverage reaches **109/109 (100%)**, 8/8 files.
All 140 `src` functions are now genuinely *called* from tests — `cyrius coverage` counts a
bare mention, so the last one (`vani_err_print_name`) was actually invoked rather than
left to inflate the number.

New coverage: the recovery policy (6 tests), the interval flags (7), and the residue that
was reachable without hardware — open/configure failure paths, the observability
emitters, `_vani_mixer_elem_info` against a closed fd, `_hwp_interval_flags` directly.

Every new group was **mutation-tested**. That caught a defect in my own work: a
"DISCONNECTED outranks SUSPENDED" precedence test passed even with the checks reordered,
because kernel states are distinct scalars and the branches are mutually exclusive —
there is no precedence to assert. The source comment claiming the ordering was
"deliberate and asserted" was wrong and is corrected; the test was replaced with one that
pins what actually matters (each action is produced by exactly one state), which does
catch a collapse mutant.

### Verified

- `cyrius test` **893/893**; lint 0 warnings / 0 untracked deferrals; fmt clean; vet
  clean; distlib regenerates clean; `CYRIUS_DCE=1` builds clean with zero warnings on
  x86_64 / aarch64 / agnos; all 9 programs build; security scan clean.
- **Benchmarks: no regression, measured the right way this time.** A same-session A/B
  against tag `1.2.1` — the method the 1.2.1 audit concluded should be the default —
  gives `ring_200ms_playback` 84,735 / 83,838 (1.2.1) vs 83,065 / 83,444 (1.2.2),
  `hwp_init_any` 918 / 937 vs 945 / 905, and `hwp_interval_set_exact` **9 vs 9**. That
  last one also retires the "+1 ns" 1.2.1 reported for its new range guard: it was noise.
- Binary: x86_64 515,320 → **515,432 B**; aarch64 → 744,656; agnos → 494,144.

## [1.2.1] — 2026-08-20

The tail of the 1.2.0 P(-1) sweep. 1.2.0 shipped with seven code-level P2 items filed
but not fixed; a follow-up pass over the tree found they were all cheap, so they are
closed here rather than carried. Same sweep, same evidence — see
[`docs/audit/2026-08-20-v1.2.0-audit.md`](docs/audit/2026-08-20-v1.2.0-audit.md) for how
each was found, and the 1.2.1 addendum for what closing them changed.

No API change (109 / 25, unchanged). Toolchain pin unchanged at 6.5.32.

### Fixed

- **Close was not idempotent** (LOW). `vani_close`, `audio_close` and
  `vani_mixer_close` each closed the descriptor but left the slot populated, so a second
  call closed a descriptor the kernel may already have recycled to a different owner. All
  three now zero the slot and return early on a repeat call. No in-tree path
  double-closes — this is hardening for out-of-tree consumers.

- **`VANI_ERR_DISCONNECTED` was produced by nothing** (LOW). A public error code since
  v0.2.0, but `SND_PCM_STATE_DISCONNECTED` (kernel state **8**) was absent from
  `AlsaPcmState`, `vani_state_from_raw` clamped its range at 7, and no path constructed
  the error. So an unplugged device was indistinguishable from a transient write failure
  — and worse, **the retry logic treated it as recoverable** and would re-prepare a
  device that is physically gone. `playback.cyr`'s own header comment claimed the
  negative returns map to "XRUN, suspended, disconnected"; two of the three were true.

  Now wired end to end: the state constant exists and is pinned against the kernel value,
  `vani_state_from_raw` accepts [0,8], `vani_state_name` reports it, and both transfer
  paths return `VANI_ERR_DISCONNECTED` without retrying.

  **Behaviour change, deliberate**: raw state 8 previously mapped to
  `VANI_STATE_UNKNOWN` and now maps to `VANI_STATE_DISCONNECTED`. A caller treating
  UNKNOWN as "device is gone" now gets the specific state instead — which is what the
  typed enum was for. Strictly speaking this is a semantic refinement on a symbol frozen
  by ADR 0002; it is shipped in a patch because the previous behaviour was simply wrong
  and no consumer can have depended on "unknown" for a state the kernel names.

- **`_hwp_interval_set_exact` truncated silently** (LOW). It `store32`s its i64 argument
  into the u32 `snd_interval.min/max` with no range check while the handle cached the
  untruncated value — so an out-of-u32 rate or period left the device running at one rate
  and reporting another. Now rejected rather than truncated.

- **`_hwp_mask_set_value` did not enforce its documented `[0,255]` bound** (INFO), which
  its read-side twin `_hwp_mask_has_bit` has always had. Unreachable from any in-tree
  caller — all pass enum constants — but `vani_format_new` stores `alsa_fmt` unvalidated,
  and a violating value was confirmed by probe to write outside the mask and, past
  ~4576, outside the 608-byte struct entirely. Now enforced.

- **`audio_set_sw_params` accepted `avail_min == 0`** (LOW), which the kernel rejects with
  `-EINVAL`, surfacing as an opaque `VANI_ERR_SW_PARAMS`. Rejected up front so the
  failure names its own cause. Both in-tree callers pass a period floored at 16, so
  nothing changes for them.

- **`boundary` was documented as an input to `audio_set_sw_params`.** It is a
  kernel-owned **output** — `snd_pcm_sw_params()` computes it from `buffer_size` and
  writes it back, ignoring whatever vani stored. Described as "`boundary =
  AUDIO_FRAMES_MAX` (2^28 — plenty of wraparound headroom)" from v0.4.0 through 1.2.0.

- **Four comments still referenced the deleted stdlib `audio.cyr`** (`src/lib.cyr`,
  `src/format.cyr`, `src/device.cyr` ×2). Same rot as the eleven fold-in claims 1.2.0
  corrected, and missed there because that pass grepped for "5.8.0" rather than for the
  filename.

### Verified

- `cyrius test` **778/778** (was 775 at 1.2.0 — three new assertions covering the
  widened state range and the `DISCONNECTED` constant). `cyrius lint` 0 warnings /
  0 untracked deferrals, `cyrius fmt --check` clean, `cyrius vet` clean, distlib
  regenerates clean, `CYRIUS_DCE=1` builds clean with zero warnings on x86_64 / aarch64 /
  agnos, all 9 programs build, security pattern scan clean. Clean-room build is
  byte-identical to the working tree.
- **API surface unchanged at 109 / 25** — this release adds constants and guards, not
  functions.
- **Benchmarks: no measurable cost, established by a same-session A/B.** Two of the
  guarded functions are directly benchmarked, so this needed checking. Comparing the
  1.2.1 numbers against the *recorded* 1.2.0 row suggested a regression
  (`hwp_interval_set_exact` 8 → 10 ns, `hwp_mask_set_value` 19 → 21, `hwp_init_any`
  920 → ~1,020). **That comparison was invalid** — the two rows come from different
  measurement sessions, and this machine is running ~8% slower than when the 1.2.0 row
  was taken.

  Rebuilding the tagged 1.2.0 tree and benching it in the *same* session gives the real
  answer:

  | Benchmark | 1.2.0 (same session) | 1.2.1 |
  |---|---|---|
  | `hwp_mask_set_value` | 21 ns | 21 ns — **no change** |
  | `hwp_init_any` | 1,030 / 1,031 ns | 1,008-1,042 — **no change** |
  | `hwp_interval_set_exact` | 9 ns | 10 ns — **+1 ns, at the resolution limit** |
  | `ring_200ms_playback` | 90,262 / 91,384 ns | 91,557-91,639 — unchanged code |

  So the guards cost nothing measurable beyond possibly 1 ns on one function, and that
  one is configuration-time anyway: all three `_hwp_init_any` call sites
  (`audio_set_params_fmt`, `audio_query_caps`, `audio_can_set_params`) run at device
  setup, and `audio_write` issues no hw_params ioctl at all.

  The `bench-history.csv` row for 1.2.1 is the raw measurement and is therefore ~8% above
  the 1.2.0 row on unchanged code. Cross-row comparisons in that file are only valid
  within a session.
- Binary: x86_64 511,192 → **515,320 B**; aarch64 744,512 → **744,536**; agnos
  494,000 → **494,032**.
- `cyrius-doom`, `cyrius-polyomino`, `cyrius-bb` and `mishran` all rebuild clean against
  the 1.2.1 `dist/vani-core.cyr`. `dhvani` is unchanged from 1.2.0 — still failing on its
  own pre-existing `http_body`, and still vendoring vani 1.0.0.

## [1.2.0] — 2026-08-20

Full **P(-1) scaffold-hardening sweep** — audit, refactor, hardening, repair. Cut as a
**minor** rather than a patch because it adds one public function (`audio_set_params_fmt`)
to fix a real correctness defect; SemVer says additive surface is a minor, and P(-1) is
explicitly the pre-minor gate.

Method: five parallel review lenses (CVE research, correctness, memory safety,
refactor/dead-code, test coverage), then **every non-INFO finding adversarially
re-verified by an independent agent**. That second pass mattered — it re-rated or
corrected **50 of 55** findings. Severities below are the post-verification ones, not
the finders' first estimates, and the audit doc carries the corrections ledger.

### Changed — cyrius pin 6.5.31 → 6.5.32

**Provably inert on both axes**: the 40 resolved stdlib modules are byte-identical
between the two snapshots, and cycc 6.5.31 and 6.5.32 emit a byte-identical
`vani_smoke`. Every number in this release is therefore attributable to vani's own
changes, with no toolchain term to subtract.

### Added

- **`audio_set_params_fmt(dev, rate, channels, alsa_fmt, period, buffer)`** — configure
  by explicit `AlsaFormat` instead of by bit depth. This is now the real body;
  `audio_set_params_full` and `audio_set_params` are thin wrappers that pick the default
  format for a width. Public surface **108 → 109** (core **24 → 25**); both snapshots
  refreshed. Purely additive — no existing signature changed.

### Fixed

- **The negotiated sample format never reached the kernel** (MEDIUM, `src/device.cyr`).
  `vani_configure` / `vani_configure_buffered` passed only `vani_format_bit_depth(fmt)`,
  and the raw layer rebuilt a format from the width via `_alsa_format_for_bits`. That
  mapping is one-format-per-width, so a caller's explicit `alsa_fmt` was silently
  replaced: **U8 → S8** (signedness flip), **S16_BE → S16_LE** (byte-order flip),
  **FLOAT_LE → S32_LE** (float bits read as int). `vani_format_new` takes `alsa_fmt` and
  `format.cyr`'s own comment says it "encodes signed-ness + endian" — it was then
  discarded. 3 of 7 supported formats were programmed wrong; anything using the S16_LE
  default was unaffected, which is why no consumer noticed. Now routed through
  `audio_set_params_fmt`, with the lossiness of the width mapping pinned by tests so it
  cannot be "simplified" back.

- **`audio_write_bytes` mis-sized S24_LE frames** (MEDIUM, `src/alsa.cyr`). It computed
  `channels * (bit_depth / 8)`, giving 3 bytes for S24_LE whose physical width is
  **4** (24 bits in a 32-bit slot — confirmed against libasound:
  `snd_pcm_format_physical_width(S24_LE) = 32`). On a stereo stream that made
  bytes-per-frame 6 instead of 8, so `num_bytes / bpf` requested **33% more frames than
  the caller's buffer holds** and the kernel read past its end into the DAC. vani's own
  `vani_bytes_per_sample` had this right since v0.2.0 and the two layers simply
  disagreed. New `_alsa_phys_bytes_for_bits` fixes the raw layer, and a test now asserts
  the two layers agree.

- **Ring transfers leaked a scratch buffer on every call** (MEDIUM,
  `src/playback.cyr` / `src/capture.cyr`). Both `alloc()`d a fresh buffer per call out of
  a bump allocator that never frees. Reproduced independently by two agents: **~110 MB
  RSS per 60,000 iterations**, with RSS tracking `alloc_used` ~1:1, so committed memory
  rather than virtual. The leak rate equals the stream's PCM byte rate exactly — 48 kHz
  stereo S16_LE is ~691 MB/hour — for any period size, because the zero-work early-out
  fires before the allocation. Sharpest detail: **dhvani's own `rt-safety.md` annotates
  that very call site "no alloc"** while it leaked. The buffer now lives on the
  `VaniDevice` (grown on demand, allocated once in steady state); the handle grew 48 → 64
  bytes to hold it.

- **`vani_play_from_ring` destroyed audio on any short write** (MEDIUM,
  `src/playback.cyr`). It called `vani_ring_read` — which *consumes* — **before** issuing
  the write, so a short write or an XRUN dropped the un-written remainder with no way to
  recover it. vani's own `programs/vanitone.cyr` documents the short-write contract this
  violated. Rewritten to peek → write → consume-only-what-was-accepted, via two new
  private ring helpers (`_vani_ring_peek`, `_vani_ring_advance`). On error nothing is
  consumed, so the caller keeps its audio and can retry after recovering the device.

- **Kernel-supplied counts drove unbounded loops and allocations** (MEDIUM,
  `src/mixer.cyr`). `vani_mixer_set_volume` and `vani_mixer_set_mute` looped an
  unvalidated `ELEM_INFO` count of `store64`s into a 1224-byte **stack** buffer; writes
  start at +72 in 8-byte steps, so any count above 144 ran off the end. Now bounded
  against the UAPI extent (`integer.value[]` is 128 longs), which needs no assumption
  about kernel internals — a count above 128 is already outside the struct vani is
  filling. `set_mute` additionally had no `count == 0` guard. `vani_mixer_list_elements`
  gained the same treatment: `count` bounded by a new `VANI_MIXER_MAX_ELEMS` (4096), and
  `used` **clamped to what was actually allocated** — the array is sized from the count
  pass but `used` comes from the fill pass, and the card's element set can change between
  the two ioctls.

- **`vani_record_to_ring` trusted the kernel's frame count** (LOW, `src/capture.cyr`).
  `snd_xferi.result` was used unclamped as a copy length, so a value above the requested
  frame count made `vani_ring_write` read past the scratch allocation and push adjacent
  heap into the caller's audio ring. Requires an ALSA ABI violation by the kernel, hence
  LOW. Clamped.

- **Null device handles faulted instead of erroring** (LOW, defense-in-depth).
  `audio_open_*` returns **0** on failure, and 14 `audio_*` plus 7 `vani_*` entry points
  dereferenced it without a guard while their siblings all had one. The open-then-use
  sequence documented in `src/alsa.cyr`'s own header comment **SIGSEGV'd — reproduced as
  exit 139**, and it now exits 0. LOW because no shipped consumer is known to hit it.

- **`vani_ring_new` ignored `alloc()`'s 0 sentinel** (LOW, `src/buffer.cyr`) — total
  arena exhaustion wrote to address 0. Both allocations now checked. (The wider "16 of 16
  `alloc()` sites are unchecked" finding was re-scoped on verification: only 7 return raw
  pointers whose contract vani can honour; the rest cannot be fixed from vani. The
  reachable ones on the transfer and mixer paths are done.)

- **Stale comments and stale docs.** `snd_pcm_status` was described and buffered as
  192 bytes (it is **152** — the ioctl already encoded that and the suite already
  asserted it); `snd_ctl_elem_list` was described as 280 bytes (it is **80**);
  `audio_get_state` read the 4-byte `state` field with `load64`, pulling `pad1` into the
  high word — the UAPI documents only `reserved` as zero-filled, so that was unsound
  rather than untidy. New `AlsaPcmStatusLayout` enum pins the size and offsets, and an
  assertion ties the ioctl's size bits to the constant so they cannot drift apart again.
- **The cyrius stdlib fold-in was described as future work in eleven live locations** —
  README, CLAUDE.md ×4, `src/lib.cyr`, `src/alsa.cyr`, `cyrius.cyml`,
  `docs/architecture/overview.md`, the roadmap, and the plan doc itself. It **already
  completed**: `cyrius/lib/audio.cyr` no longer exists in the toolchain snapshot and
  cyrius bundles vani as `lib/vani.cyr`. All corrected; the plan doc is marked COMPLETED
  and kept as the historical record.
- **CLAUDE.md's own closeout step 3 was unrunnable.** "Review the linker's `dead:` lines
  after smoke build" cannot produce signal — `programs/smoke.cyr` calls nothing but
  `sys_write`, so all 108 public symbols show up dead. Replaced with the cross-scan that
  actually works, including the `&fn` fnptr references a bare `name(` grep misses.
  CLAUDE.md also had the dist sizes inlined (wrong since 1.1.0, and against its own rule
  that volatile state lives in `state.md`) and named `hwp[608]` as the largest stack
  allocation when `val[1224]` has been bigger since 0.3.0. The ADR index was missing
  ADR 0002.

### Changed — refactor

- **`_puti` was byte-identical in six programs** (verified by md5) and carried the
  `i64::MIN` defect stdlib fixed at **6.4.69**: `n = 0 - n` is a no-op at `i64::MIN`, so
  the loop never runs and only the sign byte prints. All six deleted; **68 call sites**
  now use stdlib `fmt_int`. No reachable failure existed — every call site passes small
  positive values — so this is duplication cleanup, not a bug fix.
- **`programs/vanitone.cyr` had the tree's only `break` inside a `while` declaring
  `var`**, a CLAUDE.md hard rule cyrlint cannot see. Rewritten to flag + `continue`.
  Convention hygiene — no miscompilation was ever observed at any pin vani has shipped.
  The first rewrite kept `while (w < frames)` and continued on the flag, which spins
  forever; the shipped version puts the flag in the loop condition, and termination is
  proved for full-progress, short-write and immediate-stall cases.

**Deliberately not done**, on the reviewers' own recommendation: the 17 agnos `#ifdef`
seams, the four `val[1224]` mixer preambles and the EPIPE retry blocks are **not**
factored (each was assessed and argued against); the five zero-call-site stdlib includes
are **not** removed (verified they do not shrink `dist/*.deps`); the seven now-redundant
ioctl sub-assertions are **kept** (they name the drifting field in the failure message,
which the full-equality assertions cannot).

### Added — tests

**259 → 775 assertions.** Reference coverage **33% → 97%** (36/108 → 106/109 functions,
5/8 → 8/8 files). Every fix above ships with a regression assertion, and the load-bearing
ones were **validated with negative controls** rather than assumed to work:

| Negative control | Result |
|---|---|
| Reintroduce the +2 `AlsaHwParam` offset | 14 assertions fail |
| Transpose the `HW_PARAMS`/`HW_REFINE` nr byte | 2 fail (old suite: 0) |
| Flip `WRITEI` from `_IOW` to `_IOR` | 2 fail (old suite: 0) |
| Revert S24_LE stride to `bit_depth / 8` | 2 fail |
| Revert the scratch buffer to per-call alloc | 4 fail |

Also corrected here: the **`AlsaHwParam` enum has 19 members, not the 17** the 1.1.4
audit and the roadmap both claimed.

### Verified

- Gates under pinned genuine **6.5.32**: `cyrius test` **775/775**, `cyrius lint`
  0 warnings / 0 untracked deferrals across all 20 gated files, `cyrius fmt --check`
  clean, `cyrius vet` `1 deps, 0 untrusted, 0 missing`, distlib regenerates clean,
  `CYRIUS_DCE=1` builds clean with **zero warnings** on x86_64 / aarch64 (valid stripped
  ARM ELF) / agnos, **all 9 programs build**, CI security pattern scan clean.
- Binary cost of the hardening: x86_64 506,816 → **511,192 B** (+4,376); aarch64
  744,232 → **744,512**; agnos 489,624 → **494,000**.
- **Benchmarks flat — and provably so.** `ring_200ms_playback` read 82.9 / 83.2 / 84.3 /
  84.8 / 85.1 / 85.4 / 88.8 / 90.1 µs across eight runs against the 83.8 µs 1.1.4 row.
  That spread is machine noise, not variance in vani: the only functions inside the timed
  batch are `vani_ring_reset` and `vani_ring_write`, and both are **byte-identical to
  1.1.4** (`vani_ring_new` did change, but is called once outside the timed region). The
  median run is recorded in `bench-history.csv`.
- **Downstream**: `cyrius-doom`, `cyrius-polyomino`, `cyrius-bb` and `mishran` all
  rebuild clean against the 1.2.0 `dist/vani-core.cyr`. `dhvani` fails to build, but
  **identically with and without the swap** (`undefined function 'http_body'`, which
  appears nowhere in vani) — pre-existing dhvani-side breakage, not a regression. dhvani
  still vendors vani 1.0.0.
- **CVE sweep**: the incremental window since the 1.1.4 sweep (2026-08-20) is **empty and
  confirmed empty**, not padded. Going deeper found no new exposure: `compat_ioctl` /
  32-bit is structurally unreachable, ALSA UAPI shows zero drift across every pin vani
  holds, PulseAudio/PipeWire remain N/A by construction, and cyrius 6.5.31 → 6.5.32 has
  zero security-tagged changes. **Correction to the 1.1.4 audit**: its "19 new in-window
  Linux kernel audio CVEs" undercounted — the window holds ~60 after excluding the
  already-dispositioned 07-19 batch. The disposition (none reachable through vani's ioctl
  surface) is unchanged.

Full sweep at [`docs/audit/2026-08-20-v1.2.0-audit.md`](docs/audit/2026-08-20-v1.2.0-audit.md).

## [1.1.4] — 2026-08-20

### Changed — cyrius pin 6.5.5 → 6.5.31

Twenty-six toolchain releases of catch-up. **Zero semantic source change** —
every `src/*.cyr` diff in this release is whitespace or comment text, and
`git diff -w` on both dist bundles reduces to the version stamp plus one
8-line comment cross-reference, which is the proof.

Resolved stdlib moved with the pin: **40 modules**, 24 of them changed, every
one byte-identical to `~/.cyrius/versions/6.5.31/lib` after `rm -rf lib &&
cyrius deps`. Bundled sub-libraries: **yukti 2.3.2 → 2.3.8**, **patra 1.12.12 →
1.13.9**, **sakshi 2.4.7 → 2.4.11**.

#### Binary-size attribution — a clean 2×2

`(cycc version) × (pinned stdlib snapshot)`, each axis varied independently via
hybrid `CYRIUS_HOME` prefixes, `CYRIUS_DCE=1`, x86_64:

| | stdlib 6.5.5 | stdlib 6.5.31 | Δ stdlib |
|---|---|---|---|
| **cycc 6.5.5** | 472,712 B | 502,720 B | **+30,008** |
| **cycc 6.5.31** | 476,808 B | 506,816 B | **+30,008** |
| **Δ cycc** | **+4,096** | **+4,096** | |

Perfectly orthogonal and exactly additive: the stdlib snapshot contributes
**+30,008 B** regardless of which compiler emits it, and the compiler
contributes **+4,096 B** regardless of which stdlib it is fed. Nominal 1.1.3
(both 6.5.5) → nominal 1.1.4 (both 6.5.31) is **+34,104 B**.

Unlike the 1.1.2 bump — where cycc version had *zero* effect on vani's emitted
bytes — this window does move them, but barely: the R+E LOAD segment grows
`0x64d00 → 0x65ce0` (**+4,064 B** of real text/rodata, rounded up to one 4 KiB
page in the file), and the RW segment is byte-identical (`0x15a60`/`0x16a60`).
Reachable-function count is unchanged at 1307; this is codegen density, not new
code.

**Where the +30,008 B actually went**, attributed by rebuilding one scratch tree
against four `CYRIUS_HOME`s that differ only in which sub-library is rolled back:

| Rolled back | `vani_smoke` | attributable |
|---|---|---|
| (none — all new) | 506,816 B | — |
| patra 1.13.9 → 1.12.12 | 494,464 B | **+12,352** |
| yukti 2.3.8 → 2.3.2 | 501,896 B | **+4,920** |
| sakshi 2.4.11 → 2.4.7 | 506,736 B | **+80** |
| all three | 489,440 B | +17,376 |

So **patra alone is 41 % of the growth — and it is 100 % dead code for vani**,
reachable only through yukti's `device_db`, which vani never enters. DCE NOPs
the bodies but its rodata survives (`strings` finds `PTRAH`, `patra: invalid
magic` in the binary). The residual ~+12,632 B is core stdlib: `alloc`
29,100 → 42,247 B, `freelist` 5,967 → 26,448 B, `io` 24,707 → 32,082 B, `fs`
13,370 → 25,553 B on disk. **No vani function moved dead → live.**

Other targets: aarch64 677,336 → 744,232 B; agnos 451,584 → 489,624 B. Both
build clean, agnos with **zero warnings — at both ends of the bump**. That last
point corrects an expectation carried from the 1.1.2 audit: the 15 stdlib
`lib/yukti.cyr` warnings it documented were already resolved upstream *before*
6.5.5, so 1.1.4 neither introduced nor fixed them.

#### `cyrius build` reads the pinned snapshot, not vendored `lib/`

First established by the 1.1.2 audit (canary function in `lib/alloc.cyr`) and
re-confirmed here by a harsher test — appending a deliberate **syntax error** to
`./lib/tagged.cyr` and rebuilding **succeeded**, byte-identical. `include
"lib/…"` resolves from `$CYRIUS_HOME/versions/<pin>/lib`; the vendored `./lib/`
is consulted only to emit the `./lib/ shadows version-pinned …` warning. So
`lib/` is editor/IDE support, and **the `cyrius = "X.Y.Z"` pin is the real
supply chain** — which is also why the 2×2 above had to vary the pin rather
than swap `lib/` contents. Promoted out of the audit doc into
[`docs/development/state.md`](docs/development/state.md), since it lived only in
an audit appendix and is load-bearing for anyone reasoning about vani's
dependencies.

#### `dist/*.deps` sidecars got more complete

`dist/vani.deps` 15 → **21** leaves (`+freelist`, `+process`, `+patra`,
`+atomic`, `+sync`, `+thread_local` — the yukti/patra transitive chain that was
previously under-reported); `dist/vani-core.deps` 3 → **4** (`+syscalls`, which
`src/alsa.cyr` plainly needs for `syscall(SYS_IOCTL, …)` and `sys_open`, and
which 1.1.1's 15→3 tightening had over-trimmed). Consumers' `cyrius deps` reads
these, so this is a real fix for downstreams that vendor the bundles.

This also **closes 1.1.2 audit finding #4** (the cosmetic `undefined function`
warnings dist-bundle consumers saw out of `lib/yukti.cyr`): with the expanded
sidecar the default resolve path emits none, where `cyrius build --no-deps`
still reproduces the old `fl_alloc` / `fl_free` / `exec_vec` / `exec_capture`
set. The trade-off is that `patra` now appears in `dist/vani.deps`, so
consumers resolving through it inherit patra's dead weight — noted in the audit
as an upstream item (yukti's `device_db` would ideally be a separate optional
fold).

### Fixed

- **CI format gate was silently inverted by the toolchain bump.** The step ran
  `diff <(cyrius fmt "$f") "$f"`, which was correct through 1.1.3. Somewhere in
  the 6.5.6–6.5.31 window `cyrius fmt <file>` changed to format **in place** and
  print nothing, so the gate compared an empty stream against every file — a
  guaranteed red, and on a writable checkout it silently rewrote sources (it
  rewrote six of vani's during this release's investigation). Restored to
  `cyrius fmt <file> --check`, which exits 0/1 and writes nothing. The bare
  `cyrfmt --check` binary is **not** an equivalent substitute: it reported CLEAN
  on the same six files `cyrius fmt --check` correctly flagged, so it is the
  weaker check and CI must not use it.
- **Formatter reflow applied** — the drift the repaired gate then found:
  continuation lines of multi-line call arguments re-indent 4 → 6 spaces.
  59 insertions / 59 deletions across `src/alsa.cyr`, `src/device.cyr`,
  `src/mixer.cyr`, `programs/latency_test.cyr`, `tests/tcyr/vani.tcyr`,
  `tests/bcyr/vani.bcyr`. Whitespace only, idempotent on a second pass, and the
  emitted binary is byte-identical across it.
- **Last untracked lint deferral closed** (`src/alsa.cyr`). cyrlint flags a
  TODO/follow-up comment carrying no cross-reference; vani's one hit was a stale
  sentence claiming the `xferi[16]` → `xferi[24]` correction was "filed as audit
  follow-up for the next P(-1) sweep". That sweep ran and closed it at **0.3.0**.
  The comment now cross-references `docs/audit/2026-04-30-audit.md` and the
  0.3.0 entry. This is cleanup, not toolchain-forced — cyrlint's output on
  vani's sources is **byte-identical between 6.5.5 and 6.5.31** (2 `sys_open`
  notes, 1 deferral, 0 warnings under both), so the bump adds no new lint
  surface. CI's lint gate now fails on untracked deferrals as well as warnings,
  since cyrlint itself exits 0 on them.

### Verified

Full sweep at [`docs/audit/2026-08-20-v1.1.4-audit.md`](docs/audit/2026-08-20-v1.1.4-audit.md)
— this also **closes the audit gap 1.1.3 left** (it shipped without one), so the
sweep covers the combined `6.4.67 → 6.5.31` distance.

- **ALSA UAPI re-pinned from scratch** against kernel `7.1.8-arch1-3` with a
  generated C probe, plus a cross-arch leg re-running the same pins as
  `_Static_assert`s under `clang --target=aarch64-linux-gnu` and
  `riscv64-linux-gnu` (negative control verified). **18/18 ioctl numbers, 11/11
  struct sizes, 40/40 field offsets clean.** One divergence found —
  `enum AlsaHwParam` numbers the 14 interval-group params **+2 above the UAPI**
  (`CHANNELS` 12 vs 10, `RATE` 13 vs 11). It has **no wire impact**: all 12 use
  sites compute `PARAM - FIRST_INTERVAL`, so the offset cancels, and `rmask` is
  written all-ones rather than `1 << PARAM`. Deliberately **not fixed here** —
  a UAPI constant edit would forfeit this patch's "bytes moved only because the
  stdlib moved" proof, and CLAUDE.md says one change at a time. Filed **P1** in
  the roadmap with the four regression assertions that would have caught it.
- **CVE sweep, 2026-07-19 → 2026-08-20, host kernel 7.1.8.** 19 new in-window
  Linux kernel audio CVEs; **zero triggerable through vani's ioctl surface.**
  Closest approach is **CVE-2026-74498** (`sound/usb/endpoint.c`, USB-audio
  `fill_max` DMA overrun) which runs directly beneath vani's `HW_PARAMS` call —
  vani is the victim with no mitigation available, since `fill_max` lives below
  the ALSA UAPI boundary. Fixed in 7.1.8; **the host is exactly at 7.1.8, so
  verified-patched with zero margin.** Downstreams below 7.1.8 on the 7.1 line
  are exposed when opening USB audio. Also noted: **CVE-2026-64490** makes
  virtio-snd a new attack-surface class for the mixer path, which prior sweeps
  (physical cards only) did not consider. cyrius itself has zero public
  advisories.
- Gates re-run from a clean tree (`rm -rf build lib && cyrius deps`) under a
  hybrid `CYRIUS_HOME` pinned to genuine **6.5.31** binaries — necessary because
  a 6.5.32 toolchain landed on the dev box mid-release and repointed
  `~/.cyrius/{bin,lib,current}`. `cyrius test` **259/259**, `cyrius lint`
  **0 warnings / 0 untracked deferrals** across all 20 gated files, `cyrius fmt
  --check` 0 drift, `cyrius vet` `1 deps, 0 untrusted, 0 missing`, distlib drift
  limited to the version stamps + the whitespace reflow, `CYRIUS_DCE=1` builds
  clean on x86_64 / aarch64 (valid stripped ARM ELF) / agnos, security pattern
  scan clean, and all 8 real-HW programs build. The clean-room `vani_smoke` is
  **byte-identical** to the working-tree build. API surface holds at **108**
  public fns, matching `docs/api-surface.snapshot` exactly — no drift, as a
  patch requires; core holds at 24.
- Incidentally A/B'd along the way: cycc **6.5.31 and 6.5.32 emit a
  byte-identical `vani_smoke`**, so the accidental 6.5.32 exposure changed
  nothing — but every number reported here was re-measured under 6.5.31.
- **Real HW, dev box (HDA Generic + HDMI + ACP):** `vani_devices` under yukti
  2.3.8 enumerates all **8 PCM endpoints** across cards 0/1/2 and matches the
  documented baseline **exactly** — same cards, devices, directions, drivers,
  names and `hw_id`s. The yukti 2.3.2 → 2.3.8 bump does not disturb discovery.
  PCM open returned the documented non-session EACCES (the `/dev/snd/*` nodes
  are `root:audio` and the logind ACL grants `sddm`, not this shell) and all 8
  programs degraded closed with no crash. All 9 programs build with 0 warnings.
  No audible tone was pushed at 1.1.4 for that same access reason; the last
  audible confirmation remains cyrius-doom 0.30.5 (2026-06-29).
- Benches within run-to-run noise of the `31d5f08` (1.1.2) row across three runs
  on the pinned toolchain: `ring_200ms_playback` 83.9 / 85.9 / 85.6 µs (prior
  row 84.1 µs), `ring_write_64b` 160-168 ns (167), `ring_read_64b` 316-327 ns
  (328), `hwp_init_any` 934-956 ns (991). Measured on a machine under heavy
  concurrent load, and nothing in this bump touches a benched code path. New
  `bench-history.csv` row appended.

## [1.1.3] - 2026-08-02

### Changed — cyrius pin 6.4.67 -> 6.5.5

Toolchain catch-up across the whole desktop stack, cut together so the next burn runs binaries built
by ONE compiler rather than 6 different ones.

⚠ **The pin was documentation, not enforcement.** `cyrius build` compiles with the INSTALLED `cycc`,
prints a `toolchain drift` warning, and carries on — so this project was already being built by 6.5.5
before this bump. Verify provenance with `~/.cyrius/versions/<pin>/bin/cyrius` when it matters.

⭐ What the gap actually contained, for a reader deciding whether to care:
- **6.5.1** made overload-suffix arity a hard **error** where it used to warn. Latent arity
  mismatches are now build failures instead of silently-wrong code — good, and the reason this
  sweep surfaced real defects elsewhere in the stack.
- **6.4.75** fixed `fn_table` growth past 8192 silently corrupting six fn-indexed side tables.
- **6.5.0** added file-scoped `private` / per-item `public` — the first real answer to this
  ecosystem's duplicate-`fn`-silently-shadows hazard.
- **6.4.82** completed the agnos GPU syscall wrapper band to `#82`-`#95`, so `sys_gpu_shader_op`
  (#92) and `sys_gpu_modeset_op` (#93) no longer need a raw `syscall()` behind an `#ifdef`.

### Verification

Host + `--agnos` builds green; 1 suite passes; `distlib` regenerated.


## [1.1.2] — 2026-07-19

### Changed

- **cyrius pin `6.4.49` → `6.4.67`.** Toolchain + stdlib refresh only — **zero
  source lines changed**. Proven inert by a 2×2 A/B over `(cycc version) ×
  (stdlib snapshot)` with each axis varied independently via hybrid
  `CYRIUS_HOME` prefixes: the emitted `vani_smoke` is **byte-identical across
  cycc versions** and depends *only* on the stdlib snapshot
  (`cycc 6.4.49 + lib 6.4.67` == `cycc 6.4.67 + lib 6.4.67` == 468,456 B;
  `cycc 6.4.49 + lib 6.4.49` == `cycc 6.4.67 + lib 6.4.49` == 456,072 B; `cmp`
  clean both ways). Every codegen entry in 6.4.50–6.4.67 — the Win64 ECALLPOPS
  ≥10-arg fix, the SIMD tail-call and cx forward-call repairs, the f64/f32
  scalar work, the panic-mode rework — therefore misses vani's emitted bytes
  entirely. Every syscall wrapper vani calls is byte-identical across the two
  trees, including *both* `sys_open` shapes (Linux `(path, flags, mode)` and
  agnos `(name, namelen, flags)` — the 1.1.1 fix stays correctly gated at
  `src/alsa.cyr:481`, `:501`, `src/mixer.cyr:97`) and the agnos sovereign
  `sys_snd_*` #64-69 band; `SYS_IOCTL` is unchanged (x86 16 / aarch64 29), so
  all 20 raw `syscall(SYS_IOCTL, …)` sites (13 in `src/alsa.cyr`, 7 in
  `src/mixer.cyr`) are untouched — they span 15 distinct ioctl numbers of the
  18 pinned (`RESET`, `PAUSE` and `CARD_INFO` are pinned but never issued). The
  new agnos GPU
  band (#82/#83, which alias `rename`/`mkdir` on Linux) is file-level gated in
  `lib/syscalls.cyr` and unreachable from vani.
- **`build/vani_smoke` grew 456,072 → 468,456 B (+12,384, +2.7%) on x86_64**;
  1186 → 1237 unreachable fns, 319,474 → 329,475 B NOPed. Pure stdlib growth,
  not vani growth — no vani function moved dead→live. aarch64 is 677,184 B
  (528,072 B NOPed); agnos grew 430,768 → 447,248 B (+16,480), the same
  stdlib-growth story. `state.md`'s `~308,857 B NOPed` row was a v1.0.0-era
  figure already stale at 1.1.1 (true 6.4.49 value: 319,474 B) and is replaced
  with measured values; the binary size CLAUDE.md names as a release metric is
  now recorded there for the first time.
- **`yukti 2.2.9` → `2.2.10`: version stamp only** — the resolved bundle diffs
  by exactly one line (`# Version:`), so `vani_open_yukti`'s entire call surface
  is bit-stable. **`patra 1.12.9` → `1.12.12` is genuinely additive** (CAS-gated
  migration off hardcoded thread-local slots onto cyrius 6.4.65's
  `thread_local_alloc()`, based at 16), but reaches vani only through yukti's
  `device_db`, which vani never enters — every `patra_*` symbol and
  `thread_local_alloc` DCE-strips as dead while the three yukti audio accessors
  stay live. vani hardcodes no thread-local slot, so the collision class the
  6.4.65 allocator closes never applied here. **18 of the 40 resolved modules
  differ** between the two trees; besides yukti and patra the notable ones are
  `thread_local` (the module carrying that allocator work), `alloc` (+ its
  `_agnos`/`_macos`/`_windows` variants), `chrono`, `io`, `sakshi`, `syscalls*`,
  and `args_macos`. Still 40 modules total — no new stdlib dependency, and
  `[deps] stdlib` in `cyrius.cyml` is unchanged.
- **One user-visible behavior delta, in a range nothing reaches.** cyrius
  **6.4.50** raised `ALLOC_MAX` 256 MiB → 2 GiB (`lib/alloc.cyr:169`, `0x10000000` →
  `0x80000000`), so `vani_ring_new` for capacities in (256 MiB, 1 GiB] — under
  vani's own `VANI_RING_MAX_BYTES` ceiling of 1 GiB (`src/buffer.cyr:31`) — now
  allocates for real where it previously returned a ring with a NULL payload.
  256 MiB is ~23 minutes of 48 kHz stereo S16; no shipped call site and no
  realistic consumer enters the window, and the change fails in the safe
  direction. (The stdlib's own inline comment credits v6.4.51; the installed
  6.4.50 snapshot already carries the new value, so 6.4.50 is the real landing.)
- **`dist/vani.cyr` and `dist/vani-core.cyr` are byte-identical to 1.1.1 apart
  from the version stamp** (82,799 B / 2251 lines and 34,653 B / 939 lines,
  both unchanged); the `.deps` sidecars are unchanged at 15 / 3 leaves — no
  repeat of 1.1.1's `core.deps` churn. API surface holds at **108** public fns,
  matching `docs/api-surface.snapshot` exactly — no drift, as a patch requires.

### Verified

- Gates re-run under 6.4.67 from a clean tree (`rm -rf build lib && cyrius
  deps`): `cyrius test` **259/259**, `cyrius lint` **0 warnings** across all 20
  gated files, `cyrius fmt` 0 drift, `cyrius vet` `1 deps, 0 untrusted, 0
  missing`, distlib drift limited to the two version stamps, `CYRIUS_DCE=1`
  builds clean on x86_64 / aarch64 (valid stripped ARM ELF) / agnos, and all 8
  real-HW programs build. cyrlint's output is **byte-identical** between 6.4.49
  and 6.4.67 (3 notes, 1 untracked deferral, 0 warnings under both), so the
  bump adds no new lint surface and CI's `^\s*warn ` gate is unaffected. CI and
  release read the pin from `cyrius.cyml` — no hardcoded version in either
  workflow.
- Benches within run-to-run noise of the `59dd681` baseline across three runs:
  `ring_200ms_playback` 82.7 / 83.6 / 84.1 µs (baseline 82.96 µs),
  `ring_write_64b` 167 ns, `ring_read_64b` 328 ns, `hwp_init_any` 991 ns,
  `negotiate_format_pick` 10 ns. Since the compiled bytes are provably
  identical to 1.1.1's, the spread is machine state and is explicitly **not**
  triaged as growth-tax. New `bench-history.csv` row appended.
- **ALSA UAPI re-pinned from scratch** against `linux-api-headers 7.1-1`
  (running kernel 7.1.3): a generated C probe confirms all **18** pinned ioctl
  numbers and all **8** pinned struct *sizes* match byte-for-byte — **0
  mismatches**, including the v1.0.0 PAUSE correction. Of those 8, six map to
  exact in-tree buffers (`hwp[608]`, `swp[136]`, `xferi[24]`, `info[272]`,
  `list[80]`, `val[1224]`); `snd_ctl_card_info` has no buffer (never issued),
  and `snd_pcm_status` is over-allocated as `var status[192]` against a real
  152 — safe, but the comment at `src/alsa.cyr:910` contradicts the correct
  table entry at `:79` and is filed for 1.2.0. Eight in-window Linux kernel audio
  CVEs (plus three Windows `usbaudio.sys` ones, N/A — vani has no Windows
  target) published 2026-06-25 → 2026-07-19; none is triggerable through
  vani's ioctl surface.
  Closest approach is CVE-2026-64134 (`sound/core/pcm_lib.c`, bogus `iov_iter`
  for silencing), doubly unreachable — the kernel gates on
  `runtime->silence_size > 0` and vani hard-zeroes both `SWP_SILENCE_THRESHOLD`
  and `SWP_SILENCE_SIZE` in every SW_PARAMS (`src/alsa.cyr:658-659`), and the
  NULL deref is RISC-V-specific. cyrius itself has zero NVD entries. Full
  triage in [`docs/audit/2026-07-19-v1.1.2-audit.md`](docs/audit/2026-07-19-v1.1.2-audit.md).
- Real-HW: `vani_devices` enumerates all **8 PCM endpoints** on the dev box
  under yukti 2.2.10, matching the documented baseline exactly. PCM open
  returns the documented non-session EACCES (nodes are `root:audio`; the shell
  has no `audio`-group / logind-ACL grant), and every program degrades closed —
  unchanged behavior, not a regression.
- **Correction to 1.1.1's release note.** 1.1.1 claimed agnos "builds clean".
  It does build (`OK`), but emits **15 warnings, all originating in stdlib
  `lib/yukti.cyr`** — 8 duplicate-symbol (`SYS_SOCKET`/`CONNECT`/`BIND`/
  `RECVFROM`/`SETSOCKOPT`/`PPOLL`/`STATFS`/`NEWFSTATAT`), 6 syscall-arity
  (`sys_mount` ×3, `sys_rmdir`, `sys_unlink`, `sys_stat`), 1 undefined
  (`sys_umount2`). All sit in storage/network enumerators vani never calls, all
  dead-strip, and the set is **identical under yukti 2.2.9 and 2.2.10**
  (A/B'd via hybrid `CYRIUS_HOME` prefixes) — this bump neither introduced nor
  fixed any of them. Tracked as an upstream yukti item, not a vani defect.

## [1.1.1] — 2026-07-11

### Changed

- **cyrius pin `6.4.10` → `6.4.49`.** Staging bump ahead of the cyrius
  6.4.50 vani fold-in. The `6.4.10 → 6.4.49` delta is additive from vani's
  vantage — no source change was required to build clean. Builds + tests
  green on x86_64, aarch64 (cross), and agnos (`--agnos`).
- **`dist/vani-core.deps` tightened `15 → 3` stdlib leaves** (`string`,
  `alloc`, `tagged`). Not a behavior change: 6.4.49's `distlib` records the
  minimal transitive *roots* for the single-module core profile instead of
  6.4.10's flattened closure — `alloc`/`string` already pull `syscalls` (and
  the rest) transitively, so a consumer's `cyrius deps` resolves the identical
  set. `dist/vani.deps` (full profile) is unchanged at 15. Both `.cyr`
  bundles are byte-identical to 1.1.0 apart from the version stamp + the
  mixer fix below.

### Fixed

- **`vani_mixer_open` used the Linux 3-arg `sys_open` shape on agnos (P1,
  correctness — fails safe today).** `src/mixer.cyr` called
  `sys_open(path, 2, 0)` unconditionally. On Linux that is
  `(path, O_RDWR=2, mode=0)` — correct. On agnos `sys_open` is the
  length-carrying `(name, namelen, flags)` shape, so the same call passed
  `namelen = 2` / `flags = 0`, mis-opening a 2-byte garbage path `AO_RDONLY`
  instead of the control node. There is **no `/dev/snd/controlC{N}` on
  agnos** (the sovereign `snd_*` #64-69 band is output-only, no control
  surface), so the site could never succeed there and failed for the wrong
  reason. Fixed by an `#ifdef CYRIUS_TARGET_AGNOS` branch that **fails closed**
  (`VANI_ERR_MIXER_OPEN`) until a control syscall band lands, mirroring
  `audio_open_capture`'s agnos branch in `src/alsa.cyr`; the Linux `#else`
  path is unchanged. Same conversion family as the cyrius `file_open` /
  sakshi `_sk_open` agnos-RDWR bug. Compile-verified on all three targets;
  no public API or Linux-behavior change.

### Verified

- Gates under the new pin: `cyrius build` (x86_64 + `--aarch64` ELF +
  `--agnos`) clean, `cyrius test` **259/259**, `cyrius lint` / `cyrius fmt
  --check` / `cyrius vet` clean, distlib drift limited to the intended mixer
  `#ifdef` + version stamp + `core.deps` root-set. `cyrius bench`
  `ring_200ms_playback` 81.8 µs — within noise of the ~80.9 µs baseline
  (mixer open touches no bench path). No new ALSA / sound CVEs actioned this
  patch; the change removes a malformed agnos syscall (net defense-in-depth).

## [1.1.0] — 2026-07-10

### Added

- **Non-blocking sink API for multi-proc audio — `audio_write_nb` + `audio_avail`.**
  A blocking `audio_write` holds the CPU with preemption disabled for a whole block
  on agnos (the kernel cannot preempt a blocking syscall — the shared per-CPU syscall
  kstack, the *serial-kstack invariant*), which starves a concurrent producer process.
  `audio_write_nb(dev, buf, frames)` hands the kernel `snd_write`'s NONBLOCK bit
  (a4 bit0, `sys_snd_write_nb` #66) so it accepts only what fits in the DAC ring right
  now and returns immediately; `audio_avail(dev)` reports the ring's free frames
  (`sys_snd_avail` #69, non-blocking). A cooperative caller pairs the two — write when
  there's room, `sched_yield` #44 to donate the slice when there isn't — so two procs
  can share the one hardware writer without one blocking the other. agnos-only; on
  Linux (real preemption) `audio_write_nb` delegates to `audio_write` and `audio_avail`
  reports "always room" (the blocking write paces). First consumer: the mishran mixer's
  cooperative `msh_router_pump`, ~~proven two-proc on agnos (client → loopback → mixer →
  vani → HDA, non-silent wav)~~. No public breaking change — `audio_write` is unchanged.

  ⛔ **RETRACTED 2026-08-03 — FALSE GREEN, produced by the `MISHRAN_DUPLEX_SELFTEST` kernel
  hook's `net_ip = 0x7F000001` assignment.** agnos puts `net_ip` in an outbound SYN's SOURCE, so
  a client dialling 127.0.0.1 on an ordinary boot gets its SYN-ACK addressed to `net_ip`,
  `tcp_find_conn` never matches, and the connect dies; the hook forced src == dst so the
  handshake closed only under it. Hook, its `build.sh` define and
  `mishran-duplex-audio-smoke.sh` are deleted — do not look for the script. **The API shipped in
  this version is unaffected**: `audio_write_nb` (#66 NONBLOCK) and `audio_avail` (#69) are real,
  frozen and unchanged, and the single-proc `vanitone` agnos validation elsewhere in this file is
  honest. What is void is the specific claim that two procs were demonstrated sharing the
  hardware writer on agnos — that must be re-established over the agnos socket (`anu`), the
  local transport that replaces TCP-on-loopback. See agnos
  `docs/development/planning/ipc.md` §9-§10 and mishran's `[0.4.1]` CHANGELOG retraction.

## [1.0.0] — 2026-07-06

**Stable.** The full `vani_*` public surface (106 symbols) is frozen under
SemVer. This is a **drop-in upgrade** for every existing consumer — no
consumer-facing breaking changes (see **Breaking** below).

### Added

- **Full-surface consumer validation — `dhvani` 2.1.2.** dhvani's
  `src/playback.cyr` bridges its f64 `AudioBuffer` ↔ vani's interleaved
  S16/S24/S32 PCM, exercising the full device path live:
  `vani_open_playback` / `vani_open_capture`, `vani_ring_new` / `_write` /
  `_read`, `vani_play` / `vani_play_from_ring`, `vani_record` /
  `_record_to_ring`, `vani_configure`, `vani_format_new`, `vani_alsa_for`,
  `vani_start`, `vani_close`. This clears the last v1.0 blocker — before
  dhvani the full `vani_*` surface had **zero** live-consumer validation
  (only the 22-symbol `audio_*` core was consumer-proven, via doom /
  polyomino / bb). The two remaining consumer-unvalidated corners
  (`vani_open_yukti`, `src/mixer.cyr`) stay internally test-covered.
- **Core-sink consumer — `mishran` 0.2.0** (the AGNOS software audio mixer /
  routing daemon) wires vani as its single hardware writer:
  `msh_router_open` / `_pump` (with `-EPIPE` XRUN recovery) / `_close` over a
  vendored `vani-core.cyr`. **Verified on real hardware** (2026-07-06); degrades
  clean without `audio`-group access.
- **`test_pause_ioctl_encoding`** regression assertion (test count 258 → 259).

### Changed

- **cyrius pin `6.4.3` → `6.4.10`.** The `6.4.x` delta is the SIMD-compute
  arc (f32/int SIMD, AVX2) — purely additive, unused by vani — plus the
  6.4.10 top-level-bare-array sizing fix (a **no-op** for vani: all `var X[N]`
  are function-local) and the bench-CSV µs 10× bug fix (CSV rows trustworthy
  again). Builds clean on x86_64 / aarch64.
- **API-surface baseline reflowed + refrozen at 106.** `audio_set_params_full`
  has been arity **6** since v0.3.0, but its 2-line signature made
  `cyrius api-surface` mis-record it (`/5`, then drop it entirely). Reflowed
  to one line so the tool captures `audio_set_params_full/6`; the frozen v1.0
  baseline (`docs/api-surface.snapshot`) now matches the real surface exactly.
  **No behavior or arity change** — a tooling/baseline correction only.

### Fixed

- **`SNDRV_PCM_IOCTL_PAUSE` mis-encoded (LOW, dormant).** Was `0x00404145`;
  kernel `_IOW('A', 0x45, int)` = `0x40044145` (the `64` sat in the size
  field where the WRITE-dir bit belongs — the WRITEI/READI `_IOC` size-class
  the 2026-04-30 audit fixed). Harmless today (PAUSE has no wrapper and is
  never invoked), corrected + regression-pinned so a future `audio_pause()`
  inherits a correct number. Surfaced by the v1.0 CVE/ABI research sweep.

### Verified

- P(-1) / closeout audit: [`docs/audit/2026-07-06-v1.0.0-audit.md`](docs/audit/2026-07-06-v1.0.0-audit.md).
- `cyrius test`: **259 passed, 0 failed**. `lint` 0 warnings, `fmt --check`
  clean, `vet` clean, `distlib` drift byte-clean, `api-surface` 106 exact.
- ALSA / `sound/*` CVE sweep 2026-05-01 → 2026-07-06: no CVE triggerable
  through vani's ioctl surface (CVE-2026-53242 `snd_pcm_drain` is
  reached-but-not-triggerable — vani never links streams; USB / control-ADD
  CVEs N/A by construction).

### Breaking

- **None for any consumer.** The single pre-1.0 breaking change on record
  (`vani_open_yukti` `(desc, direction)` → `(desc)`, at v0.3.0) affected a
  non-functional stub with no consumers. `audio_set_params_full` has been
  arity 6 since v0.3.0 (the baseline `/5` was a signature-parse artifact, not
  a real signature). Upgrading from any 0.9.x to 1.0.0 is drop-in.

### Security

- Dormant `SNDRV_PCM_IOCTL_PAUSE` mis-encoding corrected (see **Fixed**).
- External-data paths re-reviewed: `vani_open_yukti` validates the descriptor
  and rejects out-of-range direction; XRUN recovery is bounded; ring/format
  math is bounded by `AUDIO_FRAMES_MAX` / `VANI_RING_MAX_BYTES`.

## [0.9.9] — 2026-07-04

**Post-fold cleanup — vani is now ALL-STDLIB.** vani 0.9.8 + yukti 2.2.8 + patra
1.12.8 landed in the **cyrius 6.4.3** stdlib, so the transitional git overrides
are retired and vani consumes the sovereign stdlib directly.

### Changed

- **cyrius pin `6.4.2` → `6.4.3`** (the release that bundles vani/yukti/patra).
- **Dropped the `[deps.yukti]` and `[deps.patra]` git overrides** — both are now
  stdlib modules. Added `yukti` + `patra` (and patra's transitive `atomic` /
  `sync` / `thread_local`) to `[deps].stdlib`. Builds clean on x86_64 / aarch64 /
  `--agnos` (on agnos, patra is excluded via yukti's `#ifndef`-gated `device_db`,
  so the full `vani_*` API still resolves to the sovereign HDA path).

### Removed

- **The committed `cyrius.lock`** and the CI lock-integrity steps (the
  `Lock file present` guard + `cyrius deps --verify`). Those anchored the
  now-gone git overrides; with zero git deps the supply chain is pinned by the
  cyrius toolchain version. Matches the all-stdlib pattern of `sakshi` / `bayan`.

**Full `vani_*` device API now builds + runs on AGNOS** (0.9.7 shipped only the
lean vani-core `audio_*` shim). Proven end-to-end: `vani_open_playback` → yukti
enumeration → `audio_open_playback` → `sys_snd_*` → the sovereign HDA DAC
(QEMU play_tone, non-silent wav).

### Changed

- **`[deps.yukti]` `2.2.7` → `2.2.8`** — yukti 2.2.8 adds an agnos branch to
  `yukti_audio_devices()` (reports the one fixed HDA endpoint instead of walking
  `/dev/snd` + `/proc/asound`, which don't exist on agnos), plus agnos stubs for
  the Linux-only syscall constants its enumerator modules reference.
- **`[deps.patra]` marked `target = "linux"`** (tag stays `1.12.7`) — patra
  (yukti's `device_db` backend) is Linux-only; `target = "linux"` drops it from
  the agnos build (agnos has no device-history store; yukti 2.2.8 gates `device_db`
  off there to match). It materializes normally for vani's Linux build.
- **Added `atomic` / `sync` / `thread_local` to `[deps].stdlib`** — patra 1.12.7's
  transitive stdlib requirements, which the cyrius 6.4.x strict transitive-dep
  check now requires named explicitly (they were tolerated implicitly under the
  old pin). All three have agnos branches, so they are target-safe.

### Notes

- Both audio paths now work on agnos: the lean **`dist/vani-core.cyr`** shim
  (what `cyrius-doom` consumes) and the **full `vani_*` API** via yukti. On agnos
  yukti reports a single fixed HDA endpoint — multi-device enumeration is a
  Linux-only concern (agnos has one audio output).
- **Release ordering:** yukti **2.2.8** must be tagged before/with this vani cut
  (the `[deps.yukti]` git tag resolves against it); local verification used a
  `path = "../yukti"` override, dropped from the committed manifest.

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
