# Vani — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** — durable rules that change rarely. Volatile state (current version, test/bench counts, real-HW verification hosts, in-flight work, recent releases) lives in [`docs/development/state.md`](docs/development/state.md), bumped every release. Do not inline state here — inlined state rots within a minor.

---

## Project Identity

**Vani** (Sanskrit: वाणी — voice, speech. Saraswati's name — the
goddess of knowledge, music, and art) — Audio device I/O for the
Cyrius ecosystem. The voice of the system.

- **Type**: Cyrius shared library — two distribution profiles:
  full (`dist/vani.cyr`, 76 KB, 106 symbols) and core
  (`dist/vani-core.cyr`, 29 KB, 22 `audio_*` symbols — playback
  path only, single module from `src/alsa.cyr`)
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius` — the source of truth; current pin tracked in [`docs/development/state.md`](docs/development/state.md))
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-documentation.md)
- **Shared crates**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/shared-crates.md)

## Goal

One Cyrius library that answers "open an ALSA PCM device, push or
pull bytes, recover from XRUN" for every AGNOS audio downstream
(shravan, dhvani, naad, jalwa, shruti, agnoshi, cyrius-doom).

Vani is the **single authority for audio in stdlib** — same way
mabda is for GPU. There is no separate "raw audio" sublayer; vani
owns the ALSA ioctls end-to-end.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, test/bench/assertion counts, dist bundle size,
> real-HW verification hosts, in-flight items, recent shipped
> releases, downstream consumers. Refreshed every release.
>
> Historical release narrative lives in [`CHANGELOG.md`](CHANGELOG.md).

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Vani's layout was hand-aligned to match mabda / yukti / vidya before
`cyrius init` covered shared-library scaffolding. New AGNOS projects
should use `cyrius init {name}` to get the standard layout from the
first commit. **Do not manually re-scaffold vani** — it's already
in shape; if anything's missing, fix the standard then port back.

## Layered Architecture

```
consumer (jalwa, dhvani, …)
    ↓
vani  — single bundled module (lib/vani.cyr)
        ├─ src/alsa.cyr      raw ALSA ioctls (open, hw_params, write/read, drain)
        ├─ src/error.cyr     VaniErr + Result helpers
        ├─ src/format.cyr    VaniFormat + frame/byte math
        ├─ src/buffer.cyr    pow-of-2 byte ring
        ├─ src/device.cyr    VaniDevice handle + vani_open_yukti adapter
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

See [`docs/development/cyrius-stdlib-fold-in.md`](docs/development/cyrius-stdlib-fold-in.md) for the 5.8.0 plan.

## Dependencies

- **Cyrius stdlib** — `syscalls`, `string`, `alloc`, `str`, `fmt`,
  `vec`, `io`, `fs`, `args`, `hashmap`, `tagged`, `fnptr`,
  `freelist`, `process`, `chrono`, `patra`, `sakshi` (all ship with
  Cyrius ≥ 5.7.39). `chrono` (added 0.9.6) is a transitive
  requirement of yukti ≥ 2.2.6 (`clock_epoch_secs`), not called by
  vani's own modules.
- **Yukti (git-pinned)** — `[deps.yukti]` git override until cyrius
  re-bundles it in stdlib (exact tag in `cyrius.cyml`; current pin
  tracked in [`docs/development/state.md`](docs/development/state.md)).
  Provides the audio enumerator surface vani's `vani_open_yukti(desc)`
  consumes.
- **Patra (git-pinned)** — `[deps.patra]` git override until cyrius
  re-bundles it (exact tag in `cyrius.cyml`; current pin tracked in
  [`docs/development/state.md`](docs/development/state.md)). Pinned
  for aarch64 portability — patra 1.9.0 (cyrius-bundled) uses raw
  `SYS_OPEN` which is undefined on aarch64. See ADR 0001 for the
  override pattern.

`audio` is **no longer a stdlib dep** — vani owns that surface
in-tree at `src/alsa.cyr`. `cyrius/lib/audio.cyr` retires at 5.8.0.

Once `shravan` (codec library) exists, consumers will pair it with
vani — but vani itself stays codec-free.

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

`cyrius.lock` is the supply-chain integrity anchor for the
git-pinned yukti dep. Always committed; CI guards its presence
before resolving deps.

## Quick Start

```bash
cyrius deps                                            # resolve stdlib + yukti into lib/
cyrius build programs/smoke.cyr build/vani_smoke       # link-check
cyrius test tests/tcyr/vani.tcyr                       # CPU assertions
cyrius bench tests/bcyr/vani.bcyr                      # CPU benches
cyrius distlib                                         # → dist/vani.cyr
cyrius lint <file>                                     # static checks (CI: 0 warnings)
cyrius fmt <file> --check                              # format check (CI: diff-clean)
cyrius vet programs/smoke.cyr                          # link-time vet

# Real-HW programs (default card 1 device 0 — edit constants for your box):
./build/vani_probe                                     # silent — open/configure/prepare/close
./build/vani_caps                                      # silent — capabilities + negotiate
./build/vani_throughput                                # silent — 200 ms playback measurement
./build/vani_mixer_test                                # silent — list mixer elements + values
./build/vani_latency_test                              # silent — both presets back-to-back
./build/vani_devices                                   # silent — yukti enumerator + open round-trip
./build/vani_tone                                      # AUDIBLE — 200 ms 440 Hz square wave
```

## Architecture (flat — matches mabda / yukti / vidya)

```
vani/
├── src/                    flat library modules — zero transitive includes
│   ├── lib.cyr               — single include chain (stdlib + domain modules)
│   ├── alsa.cyr              — raw ALSA PCM ioctls (audio_*)
│   ├── error.cyr             — VaniErr codes + Result helpers
│   ├── format.cyr            — sample format struct + frame/byte math
│   ├── buffer.cyr            — pow-of-2 ring buffer (bytes)
│   ├── device.cyr            — VaniDevice handle + vani_open_yukti adapter
│   ├── playback.cyr          — vani_play + ring drain, XRUN recovery
│   ├── capture.cyr           — vani_record + ring fill, XRUN recovery
│   └── mixer.cyr             — /dev/snd/controlC{N} — volume/mute scaffold
├── tests/
│   ├── tcyr/vani.tcyr        — CPU-only suite
│   └── bcyr/vani.bcyr        — CPU benches
├── programs/
│   ├── smoke.cyr             — link-check for the full include chain
│   ├── probe.cyr             — open / configure / prepare / state / close (silent)
│   ├── play_tone.cyr         — 200 ms 440 Hz square wave (audible — user-run)
│   ├── caps.cyr              — HW_REFINE capability probe + negotiate exerciser
│   ├── throughput.cyr        — 200 ms silence playback, frames/sec + xrun count
│   ├── mixer_test.cyr        — read-only mixer enumeration
│   ├── latency_test.cyr      — low-latency + casual presets back-to-back
│   └── devices.cyr           — yukti enumerator + open round-trip
├── bench-history.csv         — bench baseline (timestamp,commit,branch,name,ns)
├── docs/
│   ├── adr/                  — architectural decision records
│   ├── architecture/         — non-obvious invariants
│   ├── audit/                — security audit reports (YYYY-MM-DD-*.md)
│   └── development/
│       ├── roadmap.md        — completed, backlog, future, v1.0 criteria
│       ├── state.md          — live state snapshot (release-bumped)
│       └── cyrius-stdlib-fold-in.md
├── scripts/
│   └── version-bump.sh       — VERSION → CHANGELOG header sync
├── .github/workflows/
│   ├── ci.yml                — lint / fmt / vet / distlib drift / test / bench
│   └── release.yml           — version gate → CI gate → DCE build → artifacts
├── cyrius.cyml               — package manifest + [build] + [lib] + [deps]
├── cyrius.lock               — supply-chain integrity (committed)
└── VERSION                   — source of truth (templated into manifest)
```

## Key Principles

- **Direct ALSA ioctls only** — no PulseAudio, no PipeWire, no
  middleware. The stack is consumer → vani → kernel. Anything else
  is a bug.
- **PCM only** — raw samples in, raw samples out. Codec work is
  shravan's job.
- **Yukti owns discovery; vani opens the device** — vani never
  scans `/dev/snd/` or `/proc/asound/`. yukti returns a descriptor;
  vani opens it.
- **Integer PCM internally** — no floats in the sample path. The
  AlsaFormat enum names FLOAT_LE for completeness; the ring buffer
  and write path are pure byte movers.
- **Stdlib includes only in `src/lib.cyr`** — domain modules stay
  flat so `cyrius distlib` produces a clean concatenated bundle.
- **Manual memory** — `alloc / store64 / load64`. Every struct has
  a header comment block with field offsets.
- **Tagged unions for errors** — `vani_ok(value)` /
  `vani_err_result(code)` via `lib/tagged.cyr`.
- **`_`-prefix private helpers; `vani_`-prefix public API.**
- **Correctness over cleverness** — kernel UAPI is the spec; pin
  every ioctl number, struct size, and field offset with a test.
- **Test after every change**, not after the feature is "done".
- **Benchmark before claiming perf** — numbers or it didn't happen.
- **One change at a time** — never bundle unrelated changes.

## Rules (Hard Constraints)

- **Read the genesis repo's CLAUDE.md first** — [agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to the GitHub API only
- Do not implement device scanning — yukti owns that
- Do not implement codecs — shravan will own that
- Do not depend on PulseAudio or PipeWire
- Do not use floating point for sample processing — integer PCM
- Do not add Cyrius stdlib includes in individual `src/*.cyr` files
  — `src/lib.cyr` owns the whole include chain
- Do not edit `lib/*.cyr` by hand — `cyrius deps` regenerates them
- Do not hardcode Cyrius toolchain versions in CI YAML — the
  `cyrius = "X.Y.Z"` pin in `cyrius.cyml` is the only source of truth
- Do not skip benchmarks before claiming performance improvements
- Do not use `sys_system()` with unsanitized input — command injection risk
- Do not trust external data (kernel ioctl returns, user args,
  yukti descriptors from outside the audited path) without
  validation
- Do not use `break` in while loops with `var` declarations — use
  flag + `continue`
- Do not add unnecessary dependencies

## Process

### P(-1): Scaffold / Project Hardening (before every minor bump)

The full P(-1) checklist (10 items) lives in
[`docs/development/roadmap.md`](docs/development/roadmap.md) under
"P(-1) — Scaffold hardening", and the per-sweep CVE research scope
under "Security & CVE sweep cadence". The roadmap is the source of
truth — this section is just the working summary:

- Runs **before every minor bump**, never skipped on a quiet release.
- Cleanliness gates: `cyrius build programs/smoke.cyr`,
  `cyrius lint`, `cyrius fmt --check`, `cyrius vet` — all clean.
- Test sweep: `cyrius test tests/tcyr/vani.tcyr` 100 % pass;
  `cyrius distlib` diff-clean.
- Bench baseline: `cyrius bench tests/bcyr/vani.bcyr` against
  `bench-history.csv`.
- **External CVE / 0-day web research** — Linux ALSA / sound/core
  / sound/pcm / sound/usb / sound/hda CVEs since prior sweep, ALSA
  UAPI struct drift, USB-audio class CVEs, cyrius toolchain CVEs.
  Map each hit to vani code paths.
- Security audit doc filed at `docs/audit/YYYY-MM-DD-audit.md`.
- HIGH / MED findings land with regression assertions.
- Even a clean sweep ships an audit doc — "swept, clean as of
  YYYY-MM-DD against kernel X.Y" — paper trail.

### Work Loop (continuous)

1. **Work phase** — roadmap items, bug fixes, real-hardware integration
2. **Build check** — `cyrius build programs/smoke.cyr build/vani_smoke`
3. **Test + benchmark additions** for new code
4. **Internal review** — performance, memory, correctness, edge cases
5. **Security check** — any new syscall usage, user input handling, buffer allocation
6. **Documentation** — CHANGELOG, roadmap, `docs/development/state.md`, any ADR the change earned
7. **Version check** — `VERSION`, CHANGELOG header in sync (`cyrius.cyml` pulls VERSION via `${file:VERSION}`)
8. **Return to step 1**

### Security Hardening (before every release)

Every release runs a security audit pass — see
[`docs/development/roadmap.md`](docs/development/roadmap.md)
"Security & CVE sweep cadence" for the vani-specific scope (kernel
ALSA CVEs, ALSA UAPI struct drift, USB-audio class CVEs, cyrius
toolchain CVEs). Minimum:

1. **Input validation** — every function accepting external data validates bounds, types, ranges
2. **Buffer safety** — every `var buf[N]` verified; N is **bytes**, max access < N, no adjacent-variable overflow
3. **Syscall review** — every syscall validated: args checked, returns handled, error paths complete
4. **Pointer validation** — no raw pointer dereference of untrusted input without bounds
5. **No command injection** — use `exec_vec()` with explicit argv; never `sys_system()` with unsanitized input
6. **No path traversal** — file paths from external input validated, no `../` escape
7. **Known CVE review** — kernel ALSA CVEs, USB-audio class, cyrius toolchain
8. **Document findings** — all issues in `docs/audit/YYYY-MM-DD-audit.md`

Severity levels: **CRITICAL** (remote / privilege escalation), **HIGH** (moderate effort), **MEDIUM** (specific conditions), **LOW** (defense-in-depth).

### Closeout Pass (before every minor/major bump)

Run a closeout pass before tagging `X.Y.0` or `X.0.0`. Ship as the
last patch of the current minor (e.g. `0.3.5` before `0.4.0`).

1. **Full test suite** — all `.tcyr` pass, zero failures
2. **Benchmark baseline** — `cyrius bench`, append to
   `bench-history.csv`; compare against prior closeout
3. **Dead code audit** — review the linker's `dead:` lines after
   smoke build; remove genuine dead code, document remaining floor
4. **Refactor pass** — consolidate the minor's additions where
   parallel codepaths / dispatch branches accreted
5. **Code review pass** — walk diffs end-to-end for missed guards,
   ABI leaks, off-by-ones, silently-ignored errors
6. **Cleanup sweep** — stale comments, unused includes, orphaned files
7. **Security re-scan** — quick grep for new `sys_system`,
   unchecked writes, unsanitized input, buffer size mismatches
8. **Downstream check** — known consumers (cyrius-doom, jalwa,
   etc.) still build against new version
9. **Doc sync** — CHANGELOG, roadmap, `docs/development/state.md`,
   CLAUDE.md (if durable content changed)
10. **Version verify** — `VERSION`, CHANGELOG header, intended
    git tag all match
11. **Full build from clean** — `rm -rf build lib && cyrius deps && CYRIUS_DCE=1 cyrius build programs/smoke.cyr build/vani_smoke` passes clean

### Task Sizing

- **Low/Medium effort**: batch freely — multiple items per work loop cycle
- **Large effort**: small bites only — break into sub-tasks, verify each before moving on
- **If unsure**: treat it as large

### Refactoring Policy

- Refactor when the code tells you to — duplication, unclear boundaries, measured bottlenecks
- Never refactor speculatively. Wait for the third instance.
- Every refactor must pass the same test + benchmark gates as new code
- 3 failed attempts = defer and document — don't burn time in a rabbit hole

## Cyrius Conventions

- All struct fields are 8 bytes (`i64`), accessed via `load64` /
  `store64` with offset
- Bump allocation via `alloc()` for long-lived data (vec, str
  internals, VaniDevice / VaniFormat handles)
- Heap allocation via `fl_alloc()` / `fl_free()` (freelist) for
  individual lifetimes — vani currently uses `alloc` only;
  freelist is available if a future XRUN-recovery path needs it
- Enum values for constants — don't consume `gvar_toks` slots
  (4,096 initialized globals limit)
- Heap-allocate large buffers — `var buf[256000]` bloats the
  binary by 256KB. Vani's largest stack alloc is the 608-byte
  `var hwp[608]` HW_PARAMS scratchpad in
  `src/device.cyr::vani_format_negotiate` — under the 64KB
  defense-in-depth threshold
- `break` in while loops with `var` declarations is unreliable —
  use flag + `continue`
- No negative literals — write `(0 - N)` not `-N`
- No mixed `&&` / `||` in one expression — nest `if` blocks instead
- `match` is reserved — don't use as a variable name
- `return;` without value is invalid — always `return 0;`
- All `var` declarations are function-scoped — no block scoping
- Max limits per compilation unit: 4,096 variables, 1,024 functions, 4,096 initialized globals
- Counting rule: only a top-level `var NAME = <non-literal>;` (call / identifier / expression initializer) consumes an initialized-globals slot; a bare integer-literal init (`var x = 42;`) takes the static-init fast path and enum members are const-folded, so neither counts. See the cyrius guide's **Global Initializers** section (`docs/guides/cyrius-guide.md` in the cyrius repo)

## CI / Release

- **Toolchain pin**: `cyrius = "X.Y.Z"` field in `cyrius.cyml [package]`. CI and release both read this; no hardcoded version strings in YAML.
- **Dead code elimination**: every `cyrius build` in CI runs with `CYRIUS_DCE=1`. Binary size is a release metric — track it in `docs/development/state.md`.
- **Tag filter**: release workflow triggers on `v[0-9]+.[0-9]+.[0-9]+` and bare `[0-9]+.[0-9]+.[0-9]+` — semver-only, optional `v` prefix.
- **Version-verify gate**: release asserts `VERSION == git tag` before building. Mismatch fails the run.
- **Lint step**: CI runs `cyrius lint` per source file. Any warning fails the build.
- **Distlib drift gate**: CI regenerates both `dist/vani.cyr` and `dist/vani-core.cyr` and rejects any diff against the committed bundles.
- **Lock-file presence gate**: CI asserts `cyrius.lock` exists before resolving deps — defends supply-chain integrity for the git-pinned yukti dep.
- **Workflow layout**:
  - [`.github/workflows/ci.yml`](.github/workflows/ci.yml) — build, lint, fmt, vet, distlib drift, test, bench, security pattern scan, docs check; reusable via `workflow_call`
  - [`.github/workflows/release.yml`](.github/workflows/release.yml) — version gate → CI gate → DCE build → artifacts (source tarball, bundled `vani-X.Y.Z.cyr`, smoke ELF, SHA256SUMS)
- **Concurrency**: CI uses `cancel-in-progress: true` keyed on workflow + ref.
- **State sync**: bump `docs/development/state.md` every release.

Both x86_64 and aarch64 are first-class CI / release targets as of
0.9.0. The cross-build step in `ci.yml` enforces a valid ARM ELF;
release ships `vani-X.Y.Z-smoke-aarch64-linux` alongside the
x86_64 binary.

## Docs

- [`docs/adr/`](docs/adr/) — architecture decision records. *Why X over Y?*
- [`docs/architecture/`](docs/architecture/) — non-obvious constraints and quirks. *What can't I derive from the code alone?*
- [`docs/audit/`](docs/audit/) — security audit reports (`YYYY-MM-DD-audit.md`).
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — completed, backlog, future, v1.0 criteria.
- [`docs/development/state.md`](docs/development/state.md) — **live state snapshot, refreshed every release**.
- [`docs/development/cyrius-stdlib-fold-in.md`](docs/development/cyrius-stdlib-fold-in.md) — cyrius 5.8.0 fold-in plan.
- [`CHANGELOG.md`](CHANGELOG.md) — source of truth for all changes.

New quirks and constraints land in `docs/architecture/` as numbered
items (`NNN-kebab-case.md`). New decisions land in `docs/adr/` using
[`template.md`](docs/adr/template.md). **Never renumber either series.**

`docs/guides/`, `docs/examples/`, `docs/sources.md` are added when
earned (downstream consumer integration patterns, science citations
— vani is currently neither).

## Documentation Structure

```
Root files (required):
  README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md,
  CODE_OF_CONDUCT.md, SECURITY.md, LICENSE,
  VERSION, cyrius.cyml

docs/ (current):
  adr/          — architectural decision records (README + template.md + NNNN-*.md)
  architecture/ — non-obvious invariants
  audit/        — security audit reports (YYYY-MM-DD-*.md)
  development/
    roadmap.md  — completed, backlog, future, v1.0 criteria
    state.md    — live state snapshot (volatile; release-bumped)
    cyrius-stdlib-fold-in.md
```

## .gitignore (Required)

```gitignore
# Build
/build/
/target/

# Resolved deps (auto-generated by cyrius deps).
# Vani has no committed lib/k*.cyr exceptions.
/lib/

# Release / toolchain artifacts
cyrius-*.tar.gz
*.tar.gz
SHA256SUMS

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Claude Code
.claude/

# Audio test files
*.wav
*.pcm
*.raw
```

`dist/vani.cyr` is **NOT** gitignored — it's the consumer-facing
artifact and the CI distlib-drift gate verifies it stays in sync
with `src/`. The `dist/*.deps` sidecars `cyrius distlib` emits
(cyrius ≥ 6.2.47) are likewise committed — consumers' `cyrius deps`
reads them to resolve vani's stdlib leaves.

`cyrius.lock` is **NOT** gitignored — it's the supply-chain
integrity anchor for the git-pinned yukti dep.

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Performance
claims **must** include benchmark numbers. Breaking changes get a
**Breaking** section with migration guide. Security fixes get a
**Security** section with CVE references where applicable.

```markdown
## [X.Y.Z] — YYYY-MM-DD
### Added — new features
### Changed — changes to existing features
### Fixed — bug fixes
### Verified — P(-1) sweep results, audit links, CI/release proof
### Breaking — breaking changes with migration guide
### Security — security fixes with CVE refs
```
