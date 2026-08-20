# Vani Development Roadmap

Forward-looking only. `CHANGELOG.md` is the authoritative record of
completed work — don't duplicate it here. Latest audit at
`docs/audit/2026-08-20-v1.1.4-audit.md` (priors:
`docs/audit/2026-07-19-v1.1.2-audit.md`,
`docs/audit/2026-07-06-v1.0.0-audit.md`,
`docs/audit/2026-05-01-v0.9.1-audit.md`,
`docs/audit/2026-04-30-v0.9.0-audit.md`,
`docs/audit/2026-04-30-v0.3.0-audit.md`,
`docs/audit/2026-04-30-audit.md`).

## Open — P1

*None open.* The 1.1.4 sweep's P1 — `enum AlsaHwParam` numbering +2 above the
kernel UAPI — was **fixed at 1.2.0**, together with every assertion listed
alongside it (all 19 members pinned against UAPI literals, group-extent
invariants, resolved interval slots, full 32-bit equality for all 18 ioctls,
`snd_ctl_elem_list` field offsets, `AlsaAccess`). Verified with a negative
control: reintroducing the +2 offset fails 14 assertions.

## Open — P2

Filed by the 1.2.0 P(-1) sweep. Everything here survived adversarial
re-verification; severities are the post-verification ones.

- [ ] **Handle invalidation on close** (LOW, API/resource-lifetime).
      `vani_close`, `audio_close` and `vani_mixer_close` leave the descriptor
      slot populated after closing it, so the handle types are not
      self-invalidating and close is not idempotent. No in-tree path double-closes;
      this is hardening for out-of-tree consumers. Zero the fd slot and make a
      second close a no-op.
- [ ] **`VANI_ERR_DISCONNECTED` is a dead taxonomy entry** (LOW). No code path
      constructs it, and `SND_PCM_STATE_DISCONNECTED` (8) is missing from
      `AlsaPcmState`, so a device unplug is indistinguishable from a transient
      write error. `src/playback.cyr:5` claims the negative returns map to
      "XRUN, suspended, disconnected" — two of three are true.
- [ ] **i64 → u32 truncation on the hw_params interval path** (LOW).
      `_hwp_interval_set_exact` narrows its i64 argument into the u32
      `snd_interval.min/max` with no range check, so an out-of-u32 rate or
      period is silently truncated rather than rejected, while the handle
      caches the untruncated value. Reject instead of truncating.
- [ ] **`_hwp_mask_set_value` has no `[0,255]` bound** while its read-side twin
      `_hwp_mask_has_bit` does (INFO/LOW). Unreachable today — `vani_format_new`
      stores `alsa_fmt` unvalidated but every in-tree caller passes an enum —
      confirmed by probe that a violating value writes outside the mask and,
      past ~4576, outside the 608-byte struct. Enforce the documented precondition.
- [ ] **Test coverage for the 22 frozen-but-uncalled public symbols.** ADR 0002
      forbids removing them, so the actionable output is coverage, not deletion.
      1.2.0 took reference coverage to 97%; these are the residue.
- [ ] **A seam for XRUN / suspend / short-write paths.** Recovery, resume and
      partial-transfer branches cannot be exercised without either real hardware
      or an injectable ioctl seam. The 1.2.0 sweep concluded more assertions
      cannot reach them — this needs a design decision, not more tests.

**Declined, recorded so they are not re-litigated** (all assessed in the 1.2.0
sweep and argued against on the merits):

- Factoring the 17 agnos `#ifdef` seams, the four `val[1224]` mixer preambles,
  or the EPIPE retry blocks in playback/capture. Each was examined; none
  improves clarity, and CLAUDE.md's refactor policy says wait for evidence.
- Removing the five zero-call-site stdlib includes (`args`, `hashmap`, `io`,
  `fs`, `chrono`) — verified they do not shrink `dist/*.deps`.
- Adopting `io.cyr`'s `xopen` / `file_open` at the three sites cyrlint flags.
  All three are inside `#ifdef CYRIUS_TARGET_AGNOS` arms that never reach
  `sys_open`; adoption is a no-op on Linux and would push
  `dist/vani-core.deps` from 4 leaves to 6.
- Deleting the seven now-redundant ioctl sub-assertions. They name the drifting
  field in the failure message ("HW_PARAMS=608 (got 352…)"), which the
  full-equality assertions cannot.

### Closed

**1.2.0 (P(-1) sweep)** closed: the `AlsaHwParam` P1 and all its assertions; the
`snd_pcm_status` 192→152 item the 1.1.2 audit filed for 1.2.0; the api-surface CI
gate; the untracked-lint-deferral gate; six duplicate `_puti` copies; the tree's
one `break`-in-`var`-loop; the eleven stale "cyrius 5.8.0 fold-in is future work"
claims (it had already completed); and CLAUDE.md's unrunnable closeout step 3.


The agnos-incorrect Linux-shaped `sys_open` in `vani_mixer_open`
(`src/mixer.cyr`, filed 2026-07-08) was **fixed in 1.1.1**: an
`#ifdef CYRIUS_TARGET_AGNOS` branch that fails closed
(`VANI_ERR_MIXER_OPEN`) — there is no `/dev/snd/controlC{N}` control
surface on agnos — mirroring `audio_open_capture`'s agnos branch. The
reachability question the filing flagged is resolved the same way: the
mixer is a Linux-only path today, and the agnos branch is now explicit.
See the 1.1.1 CHANGELOG entry.

The last **untracked lint deferral** (`src/alsa.cyr`, a stale "filed as audit
follow-up" sentence for the `xferi[16]`→`[24]` correction that 0.3.0 actually
closed) was cleared at **1.1.4**, and CI's lint gate now fails on untracked
deferrals as well as warnings.

## v0.3.0 / v0.9.0 / v0.9.1 — done

- **0.3.0** (released 2026-04-30): yukti integration —
  `vani_open_yukti(desc)` thin adapter, real-HW DEVICES PASS on
  dev box.
- **0.9.0** (released 2026-04-30, pre-1.0 RC): aarch64 cross-build
  unblocked (73-site syscall migration to stdlib wrappers; patra
  pinned at 1.9.2 via git override); CI cross-build gate
  re-enabled; release ships `vani-X.Y.Z-smoke-aarch64-linux`;
  API surface baseline captured at `docs/api-surface.snapshot`
  (106 public symbols).
- **0.9.1** (released 2026-05-01): `[lib.core]` profile. Single
  `cyrius distlib core` → `dist/vani-core.cyr` (29 KB / 22
  symbols; 62% smaller than full). Driven by cyrius-doom's
  6-of-106-symbols usage report — proposal collapsed from a
  three-cut series (0.9.1/0.9.2/0.9.3) to a single cut because
  `src/alsa.cyr` is fully self-contained (proposal's open
  question #4). Second baseline at
  `docs/api-surface.core.snapshot`. Both bundles now drift-gated
  in CI; release ships `vani-X.Y.Z.cyr` and `vani-X.Y.Z-core.cyr`.

The cyrius 5.8.0 fold-in pin (cyrius/cyrius.cyml `[deps.vani]`)
points at whatever vani tag is current at cut time — handled on
the cyrius side, not here.

## Optional pre-1.0 work (not blocking 1.0)

- [ ] **XRUN-rate benchmark under sustained load** — a stress
      harness that runs continuous playback for minutes,
      injects CPU contention (e.g. competing `while(1)` thread
      or external `stress-ng`), and counts XRUN events. New
      CSV row in `bench-history.csv` with the load-driven xrun
      rate per preset (low-latency vs casual). Useful number:
      "0 xruns under N% CPU contention for M minutes" — sets
      a baseline for ecosystem consumers to regress against.
      Skipped for the 0.9.0 P(-1) sweep because reproducing CPU
      contention reliably needs more setup than fits a release
      gate.
- [ ] **Portable `_clock_monotonic()` helper** for
      `programs/throughput.cyr` / `programs/latency_test.cyr` —
      currently x86_64-only via raw `syscall(228, ...)`. Either
      add a small `#ifdef`-dispatched local helper or upstream
      `sys_clock_gettime` to the cyrius stdlib. Lands when an
      aarch64 dev host with real audio HW becomes available.

## Hardening backlog filed by the 1.1.2 audit — **6 of 7 DONE**

All seven were confirmed pre-existing and byte-identical before and after the
1.1.2 toolchain bump. Detail in
[`docs/audit/2026-07-19-v1.1.2-audit.md`](../audit/2026-07-19-v1.1.2-audit.md).

- [x] **Guard `alloc()` returns in `vani_ring_new`** — done **1.2.0**. Both the
      40-byte header and the payload are checked, header first.
- [x] **Clamp the kernel-supplied ELEM_INFO `count` in the mixer** — done
      **1.2.0**. Both setters bound `count` against the UAPI extent
      (`integer.value[]` is 128 longs) and `set_mute` gained the `count == 0`
      guard it never had. Heap-side, `vani_mixer_list_elements` bounds `count`
      by `VANI_MIXER_MAX_ELEMS` and **clamps `used` to the allocation** — the
      1.1.2 filing asked for `used <= count` and that is what shipped. Note the
      filing's reassurance that "USB-audio is capped at `MAX_CHANNELS = 16`
      upstream" was not relied on: vani now bounds it regardless of what the
      driver does.
- [x] **Fix the stale `snd_pcm_status` size comment** — done **1.2.0**, and
      taken further than filed: the comment is corrected, the buffer is shrunk
      192 → 152, a new `AlsaPcmStatusLayout` enum pins size and offsets, the
      `load64` on the u32 `state` field is narrowed to `load32`, and an
      assertion ties the ioctl's size bits to the constant.
- [x] **Add `freelist` / `process` / `patra` to `dist/vani.deps`** — done
      **1.1.4**; the sidecar went 15 → 21 leaves and the cosmetic
      `undefined function` warnings are gone on the default resolve path.
- [x] **Upstream the stdlib-yukti agnos warnings** — resolved upstream. vani's
      `--agnos` build emits **zero** warnings, and did so at both ends of the
      1.1.4 bump, so they were fixed before cyrius 6.5.5.
- [x] **Optional lint hardening** — done **1.1.4**. CI's lint gate now fails on
      `N untracked deferrals` as well as `warn ` lines, and vani's one
      untracked deferral was closed.
- [ ] **Extend the distlib drift gate to the `.deps` sidecars**
      (`.github/workflows/ci.yml`) — still open, still low value. It covers only
      the two `.cyr` bundles. Effectively self-healing today: every release
      bumps the `# Version:` stamp inside both `.cyr` files, which forces a
      `cyrius distlib` run that rewrites the sidecars in the same operation.

## v0.5.x — hardware coverage (HW-gated)

Need access to non-onboard audio to close out v0.2.0 #6 / #7:

- [ ] **USB audio interface integration test** — `programs/probe.cyr`
      + `programs/play_tone.cyr` + `programs/throughput.cyr`
      against a real USB DAC. Target: dedicated USB-class card
      (Behringer UCA222, Focusrite Scarlett, etc.). Verifies
      that the same code path that works on HDA Generic also
      works on `snd-usb-audio` — different period grain
      constraints, different mixer element names.
- [ ] **HDMI audio integration test** — same harness against
      `pcmC0D{3,7,8,9}p` on the dev box's existing card 0
      (HDMI). Different IEC958 / channel-map constraints.
- [ ] **Sub-10ms low-latency on USB audio** — onboard HDA
      Generic rejected sub-10ms periods (kernel BDL
      alignment); USB-class cards typically accept down to
      256 frames. Verify and add a `vani_configure_pro_audio`
      preset (5ms × 4 = 20ms) that gates on the device's
      reported minimum period.

## v1.0.0 — Stable — **SHIPPED 2026-07-06**

Cut with the **full `vani_*` surface frozen** under SemVer (106 symbols).
Criteria closeout:

| # | Item | Status at cut |
|---|------|---------------|
| 1 | Multi-hardware integration coverage (3+ targets) | **Accepted as HW-gated deferral.** Onboard analog (HDA / ALC897) verified + **audible** (doom). USB + HDMI never round-tripped — **no hardware access**, not a code gap: the same frozen code path drives them. Reclassified to post-1.0 hardware coverage (see v0.5.x); does **not** touch the frozen API. |
| 2 | First downstream consumer landed: `cyrius-doom` audio upgrade | **Met — audible on real HW.** cyrius-doom 0.30.5 (tagged), core profile, S16/stereo/44100 (2026-06-29). |
| 3 | Second downstream consumer | **Met — four consumers.** doom + polyomino 0.5.1 + bb 0.8.0 (core), plus **dhvani 2.1.2 (full surface)** and **mishran 0.4.1 (core sink, real-HW verified 2026-07-06)**. ⛔ **One piece of evidence RETRACTED 2026-08-03**: "two-proc agnos audio 2026-07-10" was also listed here and is a **FALSE GREEN** — it came off the `MISHRAN_DUPLEX_SELFTEST` kernel hook's `net_ip = 0x7F000001` assignment (hook + smoke deleted), so **this criterion is NOT met by that evidence and never was**. The criterion still stands on its own: it asks for a second downstream consumer, and doom / polyomino / bb / dhvani / mishran's real-HW `pump_probe` each satisfy it independently of any agnos two-proc result. No release gate re-opens. See agnos `docs/development/planning/ipc.md` §9-§10. |
| 4 | API surface captured as v1 baseline | **Met.** `docs/api-surface.snapshot` refrozen at 106 (arity-6 `audio_set_params_full` corrected from the 2-line-signature parse artifact); `api-surface` matches exactly. |
| 5 | Public API frozen; SemVer guarantees | **Done — full-surface freeze.** dhvani validates the full ring/capture/playback/device/format surface live, so the earlier split-freeze recommendation is superseded. Two corners (`vani_open_yukti`, `src/mixer.cyr`) are frozen but consumer-unvalidated (internally test-covered) — documented, not held back. |
| 6 | Migration-guide entry for pre-1.0 breaking changes | **Done — no consumer-facing breaks.** The one pre-1.0 breaking change (`vani_open_yukti` `(desc,direction)`→`(desc)` at 0.3.0) touched a no-consumer stub. Aggregated in the 1.0.0 CHANGELOG **Breaking** section. Upgrade is drop-in. |

Post-1.0 forward work: USB + HDMI real-HW round-trip (HW-gated, above),
the yukti-adapter / mixer-control live-consumer validation, and the
optional stress-bench / portable-clock items.

## Cyrius stdlib fold-in (cross-cut) — **DONE**

Verified complete 2026-08-20 (1.2.0 P(-1) sweep): `cyrius/lib/audio.cyr`
is gone from the toolchain snapshot and cyrius bundles vani as
`lib/vani.cyr`. Nothing further is owed on either side. The section
below is the original forward-looking text, retained for the record.


Cyrius's roadmap §v5.8.0 commits to bundling vani as a sibling
distlib alongside mabda / sankoch / sigil / yukti / sandhi.
Vani-side prereqs are met (dist bundle reproducible, audit on
record, real-HW probe + throughput PASS). The cyrius-side work
(add `[deps.vani]` to `cyrius/cyrius.cyml`, delete
`cyrius/lib/audio.cyr`, refresh stdlib reference) lives in the
cyrius repo, not here. Vani waits for the cut and then has
nothing further to do — the byte-stable `audio_*` API surface
covers existing consumers transparently.

See `docs/development/cyrius-stdlib-fold-in.md` for the full
plan.

## P(-1) — Scaffold hardening (recurring)

Runs before every minor cut. Items 5–7 (CVE research + audit
filing) are non-negotiable, even on a quiet release.

| # | Item | Trigger |
|---|------|---------|
| 0 | Read CHANGELOG, prior audit — know what's been touched | each P(-1) |
| 1 | Cleanliness: `cyrius build programs/smoke.cyr` (0 warnings), `cyrius lint` (0 warnings), `cyrius fmt --check` diff-clean, `cyrius vet programs/smoke.cyr` clean | each P(-1) |
| 2 | Test sweep: `cyrius test tests/tcyr/vani.tcyr` 100 % pass | each P(-1) |
| 3 | `cyrius distlib` regenerates `dist/vani.cyr` diff-clean | each P(-1) |
| 4 | Benchmark baseline: `cyrius bench tests/bcyr/vani.bcyr` against `bench-history.csv` | each P(-1) |
| 5 | **External CVE / 0-day research (web)** — see scope below | each P(-1) |
| 6 | Internal deep review — gaps, correctness, FFI struct offsets, ioctl size encoding | each P(-1) |
| 7 | Security audit — file findings in `docs/audit/YYYY-MM-DD-audit.md` | each P(-1) |
| 8 | Regression assertions for HIGH / MED findings | each P(-1) |
| 9 | Post-review benchmarks — prove any wins | each P(-1) |
| 10 | Documentation audit — CLAUDE.md, roadmap, CHANGELOG, audit index | each P(-1) |

A clean sweep still ships an audit doc — at minimum: "swept,
clean as of YYYY-MM-DD against kernel X.Y, no new ALSA / sound
CVEs since prior sweep."

## Security & CVE sweep cadence

Each P(-1) sweep covers:

1. **Linux kernel ALSA CVEs since prior sweep** — `cve.org`,
   `oss-security@`, kernel security ML for `ALSA`,
   `snd_pcm_*`, `snd_ctl_*`, `sound/core`, `sound/pcm`,
   `sound/usb`, `sound/hda`. Map each hit to vani's ioctl
   surface — does our path touch the affected code, what
   input could trigger it.
2. **ALSA UAPI struct drift** — diff
   `include/uapi/sound/asound.h` between the kernel range we
   support and current mainline. Vani's ioctl numbers and
   struct offsets in `src/alsa.cyr` + `src/mixer.cyr` must
   still match. The two HIGH-severity post-audit findings
   from 2026-04-30 (WRITEI/READI/ELEM_LIST size mis-encoding)
   are exactly the bug class this sweep catches; pinning
   tests in `tests/tcyr/vani.tcyr::test_ioctl_size_encoding_*`
   guard against regression.
3. **USB-audio class CVEs** — `linux-usb` ML, `sound/usb/*`.
   Relevant when device handle came from a USB sound card via
   yukti.
4. **PulseAudio / PipeWire CVEs** — N/A (vani is ioctl-only),
   but record the answer rather than skip the question.
5. **Cyrius compiler CVEs** — track cyrius CHANGELOG for
   security-tagged entries.
6. **Static analysis sweep** — re-run `cyrius vet` +
   `cyrius lint` against the full src/ tree. New rules added
   between sweeps catch new bug classes for free.

**Findings doc**: `docs/audit/YYYY-MM-DD-audit.md` per sweep,
with severity (CRIT / HIGH / MED / LOW), file, line, class,
mitigation. HIGH+ findings block the next minor cut until
fixed and regression-tested.

**Cadence**: minimum once per minor bump; additionally any time
a public CVE drops against ALSA core / sound/pcm / sound/control
that scores ≥ 7.0. The cadence is calendar-loose: trigger is
"new release approaching" or "new CVE landed", not a fixed
date.
