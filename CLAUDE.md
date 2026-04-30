# Vani — Claude Code Instructions

## Project Identity

**Vani** (Sanskrit: वाणी — voice, speech. Saraswati's name — the
goddess of knowledge, music, and art) — Audio device I/O for the
Cyrius ecosystem. The voice of the system.

- **Type**: Cyrius library (include-chain) + dist bundle
- **License**: GPL-3.0-only
- **Language**: Cyrius 5.7.39 (`cyrius.cyml: cyrius = "5.7.39"`)
- **Version**: 0.1.0 — pre-implementation scaffold
- **Status**: Restarted 2026-04-30 after a partial-push lost the prior tree
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)

## Goal

One Cyrius library that answers "open an ALSA PCM device, push or
pull bytes, recover from XRUN" for every AGNOS audio downstream
(shravan, dhvani, naad, jalwa, shruti, agnoshi, cyrius-doom).

Vani is the **single authority for audio in stdlib** — same way
mabda is for GPU. There is no separate "raw audio" sublayer; vani
owns the ALSA ioctls end-to-end.

## Layered architecture

```
consumer (jalwa, dhvani, …)
    ↓
vani  — single bundled module (lib/vani.cyr)
        ├─ src/alsa.cyr      raw ALSA ioctls (open, hw_params, write/read, drain)
        ├─ src/error.cyr     VaniErr + Result helpers
        ├─ src/format.cyr    VaniFormat + frame/byte math
        ├─ src/buffer.cyr    pow-of-2 byte ring
        ├─ src/device.cyr    VaniDevice handle (wraps alsa)
        ├─ src/playback.cyr  XRUN re-prepare retry
        ├─ src/capture.cyr   XRUN re-prepare retry
        └─ src/mixer.cyr     /dev/snd/controlC{N}
    ↓
stdlib syscalls.cyr — open/close/ioctl/read/write
    ↓
Linux ALSA kernel module
```

The raw `audio_*` ioctl primitives live in `src/alsa.cyr` (lifted
from cyrius/lib/audio.cyr at v0.1.0; that stdlib path retires at
cyrius 5.8.0). The `vani_*` higher-level API stacks on top in the
same bundle. Consumers get both layers from a single
`include "lib/vani.cyr"`.

See `docs/development/cyrius-stdlib-fold-in.md` for the 5.8.0 plan.

## Dependencies

- **Cyrius stdlib** — `syscalls`, `string`, `alloc`, `str`, `fmt`,
  `vec`, `io`, `args`, `hashmap`, `tagged`, `fnptr`, `yukti`,
  `sakshi` (all ship with Cyrius >= 5.7.39)

`audio` is **no longer a stdlib dep** — vani owns that surface
in-tree at `src/alsa.cyr`. `cyrius/lib/audio.cyr` retires at 5.8.0;
until then it stays in stdlib for back-compat but vani does not
include it.

No external git deps yet. Once `shravan` (codec library) exists,
consumers will pair it with vani — but vani itself stays codec-free.

### Dependency wiring (HARD RULE — same as mabda)

`lib/` is populated by `cyrius deps` from the `[deps]` block of
`cyrius.cyml`. It is **gitignored** — a build artifact, not source.

**NEVER** replace `lib/` with a symlink to a cyrius checkout (e.g.
`ln -s /home/macro/Repos/cyrius/lib lib`). Mabda was bitten by this
exactly: any agent doing dead-code cleanup wrote through the symlink
into the cyrius repo, silently breaking other consumers.

Setup:
```bash
rm -rf lib && mkdir lib && cyrius deps
```

Never edit `lib/*.cyr` by hand. If stdlib needs a fix, fix it in
the `cyrius` repo, cut a release, bump `cyrius = "x.y.z"` in
`cyrius.cyml`, re-run `cyrius deps`.

## Quick Start

```bash
cyrius deps                                            # resolve stdlib into lib/
cyrius build programs/smoke.cyr build/vani_smoke       # link-check
cyrius test tests/tcyr/vani.tcyr                       # CPU assertions
cyrius distlib                                         # → dist/vani.cyr
```

## Architecture (flat — matches mabda / yukti / vidya)

```
vani/
├── src/                  flat library modules — zero transitive includes
│   ├── lib.cyr             — single include chain (stdlib + domain modules)
│   ├── alsa.cyr            — raw ALSA PCM ioctls (audio_*)
│   ├── error.cyr           — VaniErr codes + Result helpers
│   ├── format.cyr          — sample format struct + frame/byte math
│   ├── buffer.cyr          — pow-of-2 ring buffer (bytes)
│   ├── device.cyr          — VaniDevice handle (wraps alsa.cyr)
│   ├── playback.cyr        — vani_play + ring drain, XRUN recovery
│   ├── capture.cyr         — vani_record + ring fill, XRUN recovery
│   └── mixer.cyr           — /dev/snd/controlC{N} — volume/mute scaffold
├── tests/
│   └── tcyr/vani.tcyr      — CPU-only suite (error, format, buffer, device)
├── programs/
│   └── smoke.cyr           — link-check for the full include chain
├── docs/
│   ├── architecture/overview.md
│   └── development/
│       ├── roadmap.md
│       └── cyrius-stdlib-fold-in.md   — 5.8.0 fold-in plan
├── cyrius.cyml             — package manifest + [build] + [lib] + [deps]
└── VERSION                 — source of truth (templated into manifest)
```

## Key Constraints

- **Direct ALSA ioctls only** — no PulseAudio, no PipeWire, no
  middleware. The stack is consumer → vani → stdlib audio.cyr →
  Linux. Anything else is a bug.
- **PCM only** — raw samples in, raw samples out. Codec work is
  shravan's job.
- **yukti owns discovery** — vani never scans `/dev/snd/` or
  `/proc/asound/`. yukti returns a descriptor; vani opens the device.
- **Integer PCM internally** — no floats in the sample path. The
  AlsaFormat enum names FLOAT_LE for completeness, but the ring
  buffer and write path are pure byte movers.
- **Stdlib includes only in `src/lib.cyr`** — domain modules stay
  flat so `cyrius distlib` produces a clean concatenated bundle.
- **Manual memory** — `alloc / store64 / load64`. Every struct has
  a header comment block with field offsets.
- **Tagged unions for errors** — `vani_ok(value)` /
  `vani_err_result(code)` via `lib/tagged.cyr`.
- **Prefix private helpers with `_`** — public API uses descriptive
  names with `vani_` prefix.

## Development Process

### P(-1): Scaffold Hardening

0. Read roadmap, CHANGELOG, audit history — know what was intended
1. Cleanliness: `cyrius build programs/smoke.cyr` (0 warnings),
   `cyrius lint` (0 warnings), `cyrius fmt --check` diff-clean
2. Test sweep: `cyrius test tests/tcyr/vani.tcyr` 100% pass
3. Internal deep review — gaps, correctness, docs
4. External research — ALSA UAPI / kernel CVE sweep
5. Security audit — `docs/audit/YYYY-MM-DD-audit.md`
6. Documentation audit — CLAUDE.md, roadmap, CHANGELOG

### Work Loop

1. Work phase — roadmap items, bug fixes, real-hardware integration
2. Test additions for new code
3. Internal review — performance, memory, correctness
4. Documentation — CHANGELOG, roadmap, docs
5. Return to step 1

## CHANGELOG Format

```markdown
## [X.Y.Z] — YYYY-MM-DD
### Added — new features
### Changed — changes to existing features
### Fixed — bug fixes
### Breaking — breaking changes with migration guide
```

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not implement device scanning — yukti owns that
- Do not implement codecs — shravan will own that
- Do not depend on PulseAudio or PipeWire
- Do not use floating point for sample processing — integer PCM
- Do not add Cyrius stdlib includes in individual `src/*.cyr` files —
  `src/lib.cyr` owns the whole include chain
- Do not edit `lib/*.cyr` by hand — `cyrius deps` regenerates them
- Do not hardcode Cyrius toolchain versions in CI YAML — read
  `cyrius.cyml`
