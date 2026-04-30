# Vani Development Roadmap

Forward-looking only. `CHANGELOG.md` is the authoritative record of
completed work — don't duplicate it here. Latest P(-1) audit at
`docs/audit/2026-04-30-audit.md`.

## Handoff — pick up here when yukti 2.2.0 ships

Vani's v0.3.0 multi-device path is the only thing blocked on
upstream right now. Yukti 2.1.2 captured the audio-domain
punch list at
[`yukti/docs/development/roadmap.md`](https://github.com/MacCracken/yukti/blob/main/docs/development/roadmap.md)
(local: `~/Repos/yukti/docs/development/roadmap.md`).

When yukti 2.2.0 ships and `lib/yukti.cyr` exposes the audio
descriptor surface (`yukti_audio_devices`, `yukti_audio_card`,
`yukti_audio_device`, `yukti_audio_subdevice`,
`yukti_audio_direction`, `yukti_audio_name`, `yukti_audio_hw_id`),
do this in vani in order:

1. **Re-resolve deps**: `rm -rf lib && mkdir lib && cyrius deps`.
   The yukti 2.2.0 bundle should now contain the audio surface.
   Quick sanity: `grep '^fn yukti_audio_' lib/yukti.cyr` should
   list at least the seven accessors above.
2. **Replace the stub**: `src/device.cyr` `vani_open_yukti(desc,
   direction)` currently returns
   `VANI_ERR_YUKTI_DESCRIPTOR` with a "pending — see roadmap
   v0.3.0" detail. Replace the body with: read card / device
   / subdevice / direction off the yukti descriptor, route to
   `audio_open_playback(card, device)` or
   `audio_open_capture(card, device)`, wrap the result via the
   existing `_vani_device_wrap` helper (pass through the same
   direction value yukti returned — yukti's
   `YUKTI_AUDIO_PLAYBACK = 0` / `_CAPTURE = 1` matches vani's
   `VaniDirection` 1:1 by design, so it's a copy not a map).
3. **Add CPU tests**: hand-build a fake yukti `AudioDeviceInfo`
   buffer with known field values, call `vani_open_yukti`
   against a closed device fd path (which will fail at the
   real `open()` syscall, but the field-extraction path runs
   first — verify the right card / device get pulled). Or
   easier: test the pure-data accessor projection without
   actually opening anything.
4. **Add a `vani_devices_for_direction(direction)`
   convenience wrapper**: take a yukti vec, filter by
   direction, return a vec of vani-friendly descriptors.
   Saves consumers from importing yukti directly.
5. **`programs/devices.cyr`**: CLI that calls
   `yukti_audio_devices()`, prints each entry with vani's
   formatting, then opens the first playback device via
   `vani_open_yukti` and runs the same sequence as
   `programs/probe.cyr` (open → state → configure → state →
   close). Real-HW PASS on the dev box's onboard audio is the
   acceptance gate.
6. **CHANGELOG entry** under `[0.1.0] — Unreleased` for the
   v0.3.0 #8/#9 items now closing.
7. **Run the full P(-1) sweep before tagging 0.3.0**:
   - cleanliness gates (build / lint / fmt / vet)
   - test suite 100% pass (was 249/249 at handoff)
   - distlib diff-clean
   - bench baseline against `bench-history.csv`
   - **CVE / 0-day web research** — see "Security & CVE sweep
     cadence" below; specifically look for any new
     `sound/usb`, `sound/core`, or aloop CVEs since
     2026-04-30.
   - File new audit doc at `docs/audit/YYYY-MM-DD-audit.md`.
8. **Tag 0.3.0** once #1–#7 above are clean. Update
   `cyrius/cyrius.cyml` `[deps.vani]` (or stdlib pin)
   alongside, since the 5.8.0 fold-in pin needs to point at
   whatever vani version is current at cut time.

## Next minor — v0.4.0

The latency / SW_PARAMS / suspend-resume / preset work landed
already; one open item before the 0.4.0 tag:

- [ ] **XRUN-rate benchmark under sustained load** — a stress
      harness that runs continuous playback for minutes,
      injects CPU contention (e.g. competing `while(1)` thread
      or external `stress-ng`), and counts XRUN events. New
      CSV row in `bench-history.csv` with the load-driven xrun
      rate per preset (low-latency vs casual). Useful number:
      "0 xruns under N% CPU contention for M minutes" — sets
      a baseline for ecosystem consumers to regress against.
      Skipped for the v0.1.x cuts because reproducing CPU
      contention reliably needs more setup than a typical
      P(-1) gate.

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
| 2 | First downstream consumer landed: `cyrius-doom` audio upgrade | Awaits cyrius-doom integration |
| 3 | Second downstream consumer: one of `jalwa` / `dhvani` / `agnoshi` | Awaits those projects |
| 4 | API surface diff via `cyrius_api_surface` captured as v1 baseline | Toolchain ships the tool (5.7.33) — run when the API stops moving |
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
