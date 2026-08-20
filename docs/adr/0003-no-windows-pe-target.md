# 0003 — Windows/PE is not a supported vani target

> **Status**: Accepted
> **Date**: 2026-08-20
> **Authors**: Robert MacCracken

## Context

Through cyrius 6.5.5, a PE/Windows build of vani failed loudly at compile
time. `lib/syscalls_windows.cyr` defined no `SYS_IOCTL`, so vani's 20 raw
`syscall(SYS_IOCTL, …)` sites — 13 in `src/alsa.cyr`, 7 in `src/mixer.cyr` —
produced `undefined variable 'SYS_IOCTL'`, a hard error. The build could not
be mistaken for a working one.

Two changes in the 6.5.x window removed that signal:

- **6.5.25** made an unrouted *literal* syscall number return `-38`/`-ENOSYS`
  instead of emitting a raw `0F 05` instruction.
- Some point after 6.5.5, `lib/syscalls_windows.cyr` gained `SYS_IOCTL = 16`
  (`lib/syscalls_windows.cyr:51`). The upstream comment names vani directly:
  the symbol was added because `lib/yukti.cyr`'s CD-ROM eject path made the
  missing constant a hard error that blocked a PE build of yukti, vani and
  mabda.

Combined, a PE build of vani now **compiles cleanly and returns `-38` from
every ioctl at runtime**. That is fail-safe — every vani call site checks
`r < 0` — but it is silent. Nothing in the build output distinguishes "vani
works on Windows" from "vani compiles on Windows and does nothing."

Surfaced by the 1.2.0 P(-1) sweep (finding L-5 in
[`2026-08-20-v1.2.0-audit.md`](../audit/2026-08-20-v1.2.0-audit.md)).

## Decision

**Windows/PE is not a supported target for vani, and will not become one by
accident.** vani's contract is the Linux ALSA character-device interface and
the AGNOS sovereign `snd_*` syscall band. A PE build is not tested, not
gated in CI, and produces a library whose entire audio surface returns
`-ENOSYS`. Supported targets are exactly: `x86_64-linux`, `aarch64-linux`,
and `agnos`.

## Consequences

- The three CI legs (`x86_64`, `--aarch64`, `--agnos`) remain the definition
  of "builds". No Windows leg is added, so no maintenance burden is taken on.
- A clean PE compile carries **no** implied guarantee. Anyone who produces one
  is holding a stub, and this ADR is the answer to "but it built."
- The failure mode is safe rather than wrong: `-ENOSYS` propagates through
  `audio_*` and surfaces as a normal `VaniErr`, so a hypothetical PE consumer
  degrades closed rather than writing to a bogus handle.
- vani takes on no obligation to keep `SYS_IOCTL` out of the Windows peer.
  That symbol exists for yukti's benefit and is upstream's to manage.

**Revisit if** a real Windows consumer appears *and* someone is prepared to
write the WASAPI or WinMM backend it would need. That is a new backend behind
an `#ifdef`, in the shape of the existing AGNOS split — not a syscall
retarget. Reversing this ADR is cheap; what it would cost is the backend.

## Alternatives considered

- **Add a Windows CI leg to catch the regression.** Rejected: it would gate a
  configuration nobody uses, and a green leg would assert exactly the thing
  this ADR denies — that a PE build means something.
- **Add a compile-time guard that hard-errors on `CYRIUS_TARGET_WINDOWS`.**
  Rejected for now: vani has no such target macro in its include chain today,
  and adding a branch to defend against a build nobody performs is speculative
  — the `#ifdef` count in `src/alsa.cyr` is already the module's main
  complexity. Reconsider if anyone reports having tried it.
- **Write the WASAPI backend.** Rejected as out of scope: no consumer has
  asked, and vani's stated goal is the AGNOS audio stack.

## References

- `lib/syscalls_windows.cyr:51` — the `SYS_IOCTL = 16` definition and its
  upstream rationale comment at `:41-50`
- `src/alsa.cyr`, `src/mixer.cyr` — the 20 raw `syscall(SYS_IOCTL, …)` sites
- [`docs/audit/2026-08-20-v1.2.0-audit.md`](../audit/2026-08-20-v1.2.0-audit.md) — finding L-5
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — the three gated targets
- [ADR 0002](0002-freeze-full-vani-surface-at-1.0.md) — the SemVer freeze this sits under
