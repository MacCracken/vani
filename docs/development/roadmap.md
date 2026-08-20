# Vani Development Roadmap

Forward-looking only. `CHANGELOG.md` is the authoritative record of
completed work — don't duplicate it here. Latest audit at
`docs/audit/2026-08-20-v1.2.2-audit.md` (priors:
`docs/audit/2026-08-20-v1.2.1-audit.md`,
`docs/audit/2026-08-20-v1.2.0-audit.md`,
`docs/audit/2026-08-20-v1.1.4-audit.md`,
`docs/audit/2026-07-19-v1.1.2-audit.md`,
`docs/audit/2026-07-06-v1.0.0-audit.md`,
`docs/audit/2026-05-01-v0.9.1-audit.md`,
`docs/audit/2026-04-30-v0.9.0-audit.md`,
`docs/audit/2026-04-30-v0.3.0-audit.md`,
`docs/audit/2026-04-30-audit.md`).

## Open — P1

*None.*

## Open — P2

- [ ] **The prepare→retry sequence is still untested.** 1.2.2 made the recovery
      *decision* a pure function and covered it exhaustively; nothing proves the
      ioctls it calls for are issued in the right order, or that the retry happens
      exactly once. Narrower than the original gap, but real.
      [ADR 0004](../adr/0004-recovery-policy-seam.md) states the condition for
      revisiting: if recovery gains retry budgets, backoff, or per-direction
      policy, the sequence stops being reviewable at a glance and a mockable
      indirection becomes worth its cost.
- [ ] **`vani_format_negotiate` does not re-refine jointly.** Each dimension is
      now clamped correctly against its own interval (1.2.2 fixed the open/empty
      flags), but nothing re-runs `HW_REFINE` with the chosen rate + channels +
      format together, so a combination whose parts are individually legal can
      still be rejected by `HW_PARAMS`. Needs a second ioctl round-trip, which
      cannot be verified without hardware — deliberately not added blind.
- [ ] **No real-hardware verification anywhere in the 1.2.x line.** See
      [Hardware coverage](#hardware-coverage-hw-gated) — this is the largest
      open gap in the project.

## Declined

Recorded so they are not re-litigated. All were assessed during the 1.2.0
P(-1) sweep and argued against on the merits:

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

## Completed work

Completed work is **not** listed here — see [`CHANGELOG.md`](../../CHANGELOG.md),
which is the authoritative record. As of 1.2.2 nothing filed by the 1.2.0
P(-1) sweep, the 1.1.2 hardening backlog, or the v1.0.0 freeze criteria
remains open; the cyrius stdlib fold-in is complete.

## Unscheduled — nice to have

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

## Hardware coverage (HW-gated)

**This is the largest gap in the project**, and it has grown rather than
shrunk: the whole 1.2.x line — thirteen real defects across three releases —
was found and fixed by reading, probing and mutation testing, and **none of
it has been heard**. `/dev/snd` is EACCES for the shell those releases were
built in (the logind ACL grants `sddm`), so nothing was played.

Before trusting 1.2.x on hardware, run the eight real-HW programs plus
`./build/vani_tone` from a desktop seat session. Several fixed defects — the
S24_LE frame stride, the format that never reached the kernel, the
ring-consume ordering — sit on paths only real playback exercises.

Beyond that, non-onboard hardware access is needed for:

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

## P(-1) — Scaffold hardening (recurring)

Runs before every minor cut. Items 5–7 (CVE research + audit
filing) are non-negotiable, even on a quiet release.

| # | Item | Trigger |
|---|------|---------|
| 0 | Read CHANGELOG, prior audit — know what's been touched | each P(-1) |
| 1 | Cleanliness: `cyrius build programs/smoke.cyr` (0 warnings), `cyrius lint` (0 warnings), `cyrius fmt --check` diff-clean, `cyrius vet programs/smoke.cyr` clean | each P(-1) |
| 2 | Test sweep: `cyrius test tests/tcyr/vani.tcyr` 100 % pass | each P(-1) |
| 3 | `cyrius distlib` + `distlib core` regenerate both bundles **and both `.deps` sidecars** diff-clean | each P(-1) |
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
