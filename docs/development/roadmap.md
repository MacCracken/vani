# Vani Development Roadmap

Forward-looking only. `CHANGELOG.md` is the authoritative record of
completed work — don't duplicate it here. Latest P(-1) audit at
`docs/audit/2026-05-01-v0.9.1-audit.md` (priors:
`docs/audit/2026-04-30-v0.9.0-audit.md`,
`docs/audit/2026-04-30-v0.3.0-audit.md`,
`docs/audit/2026-04-30-audit.md`).

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

## v1.0.0 — Stable

| # | Item | Status |
|---|------|--------|
| 1 | Multi-hardware integration coverage (3+ targets) | Onboard HDA verified; USB + HDMI gated on access (see v0.5.x above) |
| 2 | First downstream consumer landed: `cyrius-doom` audio upgrade | Integration staged in cyrius-doom against vani 0.3.0 — pending the doom-side commit/tag. End-to-end smoke against shareware WAD passed (degrade path clean). |
| 3 | Second downstream consumer: one of `jalwa` / `dhvani` / `agnoshi` | jalwa / dhvani still Rust (gated on Cyrius port). agnoshi is Cyrius (4.5.0 pin) but has no audio path yet (gated on agnoshi audio roadmap). |
| 4 | API surface diff via `cyrius api-surface` captured as v1 baseline | **v0.9.0 baseline captured** at `docs/api-surface.snapshot` (106 public symbols). Diff against this at v1.0.0 freeze. |
| 5 | Public API frozen; SemVer guarantees | Set after 1–3 land |
| 6 | Migration-guide entry for any pre-1.0 breaking changes | Aggregate from CHANGELOG when freezing |

## Cyrius 5.8.0 fold-in (cross-cut)

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
