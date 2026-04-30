# Vani Development Roadmap

> **v0.1.0** — Restarted scaffold (2026-04-30). Audio device I/O for Cyrius.

The path to v1.0.0 is four minors (v0.2.0–v0.4.0 + v1.0.0) plus a
recurring P(-1) scaffold-hardening pass that runs before each
minor cut. The v5.8.0 fold-in into cyrius is a cross-cut tracked
in `cyrius-stdlib-fold-in.md` and cyrius's own roadmap (v5.8.0
section, "Vani audio distlib fold-in").

## P(-1) — Scaffold hardening (continuous; first pass before v0.2.0)

Runs before every minor bump. Models mabda's P(-1) — the goal is
"land features only on a clean tree". Items 5–7 (CVE research +
audit) are the part the user explicitly called out and should
**never** be skipped, even on a quiet release.

| # | Item | Trigger |
|---|------|---------|
| 0 | Read CHANGELOG, roadmap, prior audit — know what was intended | each P(-1) |
| 1 | Cleanliness: `cyrius build programs/smoke.cyr` (0 warnings), `cyrius lint` (0 warnings), `cyrius fmt --check` diff-clean, `cyrius vet programs/smoke.cyr` clean | each P(-1) |
| 2 | Test sweep: `cyrius test tests/tcyr/vani.tcyr` 100 % pass | each P(-1) |
| 3 | `cyrius distlib` regenerates `dist/vani.cyr` diff-clean | each P(-1) |
| 4 | Benchmark baseline: `cyrius bench tests/bcyr/vani.bcyr` (once v0.2.0 lands the bench harness) | each P(-1) from v0.2.0+ |
| 5 | **External CVE / 0-day research (web)** — see "Security & CVE sweep" section below | each P(-1) |
| 6 | Internal deep review — gaps, correctness, docs, FFI offsets, struct-packing math | each P(-1) |
| 7 | Security audit — file findings in `docs/audit/YYYY-MM-DD-audit.md` | each P(-1) |
| 8 | Regression tests for HIGH / MED findings — every fix lands with an assertion that would have caught the original bug | each P(-1) |
| 9 | Post-review benchmarks — prove the wins (if any) | each P(-1) from v0.2.0+ |
| 10 | Documentation audit — CLAUDE.md, roadmap, CHANGELOG, audit index | each P(-1) |

A P(-1) pass with no findings still ships — at minimum it produces
a dated audit doc that says "swept, clean as of YYYY-MM-DD against
kernel X.Y, no new ALSA / sound CVEs since prior sweep."

## v0.1.0 — Foundation (current)

| # | Item | Status |
|---|------|--------|
| 1 | Manifest on `cyrius.cyml` (5.7.39 pin) | Done |
| 2 | `src/lib.cyr` include chain | Done |
| 3 | Absorb `cyrius/lib/audio.cyr` → `src/alsa.cyr` | Done |
| 4 | `VaniErr` + Result helpers | Done |
| 5 | `VaniFormat` + frame/byte math | Done |
| 6 | Pow-of-2 ring buffer | Done |
| 7 | `VaniDevice` handle wrapping `alsa.cyr` | Done |
| 8 | `vani_play` + XRUN re-prepare retry | Done |
| 9 | `vani_record` + XRUN re-prepare retry | Done |
| 10 | Smoke link-check program | Done |
| 11 | CPU-only test suite (62 assertions) | Done |
| 12 | Cyrius 5.8.0 fold-in plan documented | Done |
| 13 | `dist/vani.cyr` via `cyrius distlib` | Done |
| 14 | First P(-1) scaffold-hardening pass | Done — `docs/audit/2026-04-30-audit.md` |
| 15 | Real-hardware probe (open / configure / state / close on `pcmC1D0p`) | Done — `programs/probe.cyr` PASS on real HW |
| 16 | Tag `0.1.0` on `main` once 14 + 15 close | Ready — both prereqs done |

Note: full PCM round-trip (prepare + write + capture) is blocked on
the simplified `audio_set_params` path — `vani_prepare` needs the
kernel in SETUP state, which requires
`SNDRV_PCM_IOCTL_HW_PARAMS`. That ships in v0.2.0 #2. The
v0.1.0 integration test scope is "syscall plumbing reaches the
kernel and back"; full audio I/O is v0.2.0's gate.
`programs/play_tone.cyr` is the v0.2.0 acceptance fixture — kept in
the tree, builds today, fails at prepare until HW_PARAMS lands.

## v0.2.0 — HW_PARAMS + benchmarks

The simplified `audio_set_params` path stored rate / channels /
bit_depth on the handle without negotiating with the kernel.
v0.2.0 lands the real ioctl, unblocking the OPEN → SETUP →
PREPARED state transition that `programs/play_tone.cyr` needs.

| # | Item | Status |
|---|------|--------|
| 1 | P(-1) sweep before opening v0.2.0 work | Rolled into 2026-04-30 sweep |
| 2 | Full `SNDRV_PCM_IOCTL_HW_PARAMS` struct (608 B) — interval / mask arrays packed | Done — `src/alsa.cyr` |
| 3 | `SNDRV_PCM_IOCTL_HW_REFINE` for capability query | Done — `audio_query_caps`, `audio_can_set_params`, `programs/caps.cyr` PASS on real HW |
| 4 | `vani_format_negotiate(d, preferred)` — picks closest supported format | Done — `src/device.cyr`; quality walk S32→S24→S16→S8→U8 |
| 5 | Onboard audio integration test (real PCM round-trip via `play_tone.cyr`) | Builds clean; user runs to verify audible output |
| 6 | USB audio integration test | Not started |
| 7 | HDMI audio integration test | Not started |
| 8 | `tests/bcyr/vani.bcyr` — CPU-only benches for ring + format math | Not started |
| 9 | Latency / throughput / underrun-rate measurements (CSV history) | Not started |
| 10 | Tag `0.2.0` | Not started |

## v0.3.0 — Mixer + yukti adapter

The control device is its own fd surface; vani v0.1.0 ships open /
close + the ioctl number table. v0.3.0 fills in the per-element
struct packing.

| # | Item | Status |
|---|------|--------|
| 1 | P(-1) sweep before opening v0.3.0 work | Not started |
| 2 | `snd_ctl_elem_id` (16 B iface + device + subdevice + name + index) packing | Not started |
| 3 | `snd_ctl_elem_value` (variant union, 1024 B) packing | Not started |
| 4 | `vani_mixer_set_volume` — real `SNDRV_CTL_IOCTL_ELEM_WRITE` | Not started |
| 5 | `vani_mixer_set_mute` — real `SNDRV_CTL_IOCTL_ELEM_WRITE` | Not started |
| 6 | `vani_mixer_list_elements` — `SNDRV_CTL_IOCTL_ELEM_LIST` enumeration | Not started |
| 7 | `vani_mixer_get_volume` / `vani_mixer_get_mute` (read path) | Not started |
| 8 | `vani_open_yukti(desc, direction)` — typed yukti audio descriptor adapter | Not started |
| 9 | Multi-device routing helpers (onboard / USB / HDMI selection) | Not started |
| 10 | Tag `0.3.0` | Not started |

## v0.4.0 — Latency + correctness

Pro-audio readiness. The simplified path uses kernel-default
period / buffer sizes; v0.4.0 makes them tunable and adds the
state-machine pieces (suspend/resume, typed state enum).

| # | Item | Status |
|---|------|--------|
| 1 | P(-1) sweep before opening v0.4.0 work | Not started |
| 2 | Configurable buffer size on configure (`period_size`, `periods`) | Not started |
| 3 | `SNDRV_PCM_IOCTL_SW_PARAMS` (start_threshold, stop_threshold, avail_min) | Not started |
| 4 | Suspend / resume support (handle `SUSPENDED` → `audio_resume` retry) | Not started |
| 5 | `audio_get_state` → typed `VaniState` enum (replace raw int returns) | Not started |
| 6 | Low-latency mode preset (5 ms ring, small period, tight thresholds) | Not started |
| 7 | Casual-playback preset (64 ms ring, large period) | Not started |
| 8 | XRUN-rate benchmark on real hardware under load | Not started |
| 9 | Tag `0.4.0` | Not started |

## Cyrius 5.8.0 fold-in (cross-cut)

Cyrius has committed to the fold-in for v5.8.0 — see [cyrius
roadmap §v5.8.0 "Vani audio distlib fold-in"](../../../cyrius/docs/development/roadmap.md)
(local path) and `docs/development/cyrius-stdlib-fold-in.md` for
the concrete steps. Pinned 2026-04-30.

**Vani-side prerequisites for the cyrius pin:**

| # | Item | Status |
|---|------|--------|
| 1 | Tag a public release the `[deps.vani]` block can pin to | Not started — first tag is `0.1.0` |
| 2 | At least one P(-1) sweep on record (audit doc) | Not started |
| 3 | Real-hardware integration test passing (onboard audio minimum) | Not started — v0.1.0 #15 |
| 4 | `dist/vani.cyr` reproducible from `cyrius distlib` | Done |

**Cyrius-side work** (handled in the cyrius repo, not vani):

1. Add `[deps.vani]` block to `cyrius/cyrius.cyml` — pinned to
   whatever vani tag ships at 5.8.0 cut time
2. Delete `cyrius/lib/audio.cyr` (236 LOC)
3. CHANGELOG entry calling out the include-path swap
4. Pre-flight `grep -rn 'lib/audio.cyr' /home/macro/Repos` — confirm
   no in-tree consumer still imports the old path
5. Refresh stdlib-reference + ecosystem.cyml — vani joins
   mabda / sankoch / sigil / yukti / sandhi

The `audio_*` API surface is byte-for-byte stable through the
fold-in. Whichever vani version is current at 5.8.0 cut becomes
the pinned tag — could be 0.1.0 (minimum), more likely 0.3.0+
once mixer + yukti adapter are real.

## v1.0.0 — Stable

| # | Item | Status |
|---|------|--------|
| 1 | P(-1) sweep with zero HIGH / CRIT findings | Not started |
| 2 | `dist/vani.cyr` shipped as Cyrius stdlib bundle (5.8.0+) | Not started |
| 3 | Tested on 3+ hardware targets (onboard, USB, HDMI minimum) | Not started |
| 4 | First downstream consumer landed: `cyrius-doom` audio upgrade (PC speaker → real audio) | Not started |
| 5 | Second downstream consumer: at least one of jalwa / dhvani / agnoshi | Not started |
| 6 | Public API frozen; SemVer guarantees from here | Not started |
| 7 | API surface diff via `cyrius_api_surface` is captured as the v1 baseline | Not started |
| 8 | CHANGELOG migration-guide entry for any pre-1.0 breaking changes | Not started |

## Security & CVE sweep cadence

The "external research" item in the P(-1) checklist is a
deliberate web-research pass — not a one-off. Search the public
record for what changed in the audio subsystems we touch since
the prior sweep, then map findings to vani code paths.

**Each P(-1) sweep:**

1. **Linux kernel ALSA CVEs since the prior sweep** — search
   `cve.org` and the kernel security mailing list (`oss-security@`)
   for `ALSA`, `snd_pcm_*`, `snd_ctl_*`, `sound/core`, `sound/pcm`,
   `sound/usb`, `sound/hda`. Map each hit to: does vani's ioctl
   path go through this code? if yes, what's the input we send
   that could trigger it?
2. **ALSA UAPI struct drift** — diff
   `include/uapi/sound/asound.h` between the kernel range we
   support and current mainline. Vani's ioctl numbers and struct
   offsets in `src/alsa.cyr` + `src/mixer.cyr` must still match.
3. **USB-audio class CVEs** — `linux-usb`, `sound/usb/*`. Relevant
   when the device handle came from a USB sound card via yukti.
4. **PulseAudio / PipeWire CVEs** — only relevant if vani ever
   gains a non-direct path. Today this is a no-op (vani is
   ioctl-only) but recorded so the answer is "N/A — direct ALSA
   only" rather than "did not check".
5. **Cyrius compiler CVEs** — toolchain we compile against. Track
   the cyrius CHANGELOG for security-tagged entries.
6. **`audio_*` / `vani_*` static analysis** — re-run `cyrius vet`
   + `cyrius lint` against the full src/ tree. New rules added to
   the linter between sweeps catch new bug classes for free.

**Findings doc**: `docs/audit/YYYY-MM-DD-audit.md` per sweep, with
severity (CRIT / HIGH / MED / LOW), file, line, class, mitigation.
HIGH+ findings block the next minor cut until fixed and
regression-tested.

**Cadence**: minimum once per minor bump; additionally any time a
public CVE drops against ALSA core / sound/pcm / sound/control
that scores ≥ 7.0. The cadence is calendar-loose: the trigger is
"new release approaching" or "new CVE landed", not a fixed date.
