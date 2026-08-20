# 0004 — Split recovery policy from transport; decline a mockable ioctl seam

> **Status**: Accepted
> **Date**: 2026-08-20
> **Authors**: Robert MacCracken

## Context

The 1.2.0 P(-1) sweep filed one finding it could not close: XRUN recovery,
suspend/resume and the disconnect path had **no test coverage and no way to get
any**. Reaching those branches requires a kernel that returns `-EPIPE` /
`-ESTRPIPE` on demand, which a CPU-only suite cannot arrange. The sweep's own
conclusion was that more assertions could not help — it needed a design
decision, not more tests.

The stakes are not theoretical. Two of the defects that sweep found live exactly
here: `VANI_ERR_DISCONNECTED` was produced by no path at all (so an unplugged
device was classified as a *recoverable* error and re-prepared in a loop), and
`vani_play_from_ring` consumed the ring before the write so any short write or
XRUN destroyed audio. Both sat in untested code for many releases.

Three options were on the table.

1. **Function-pointer indirection.** Route every ioctl through a
   `_audio_ioctl(fd, req, arg)` swappable at runtime via a global fn pointer,
   and install a mock in tests.
2. **Compile-time seam.** `#ifdef CYRIUS_TEST` branches in `src/` redirecting to
   a fake transport.
3. **Split the decision from the transport.** Extract "a transfer just failed —
   what now?" into a pure function of `(xfer_result, state)`, leaving the ioctl
   sequence as a thin actuator.

## Decision

**Take option 3. Extract `_vani_recovery_for(xfer_result, state)` into
`src/error.cyr` as a pure, side-effect-free classifier, and route both
`vani_play` and `vani_record` through it. Do not build a mockable ioctl
indirection.**

The classification is tested exhaustively — every kernel state including ones
vani has never seen, every action, plus `-1` for a failed `STATUS` ioctl. What
remains untested is roughly six lines per direction that issue
`prepare` / `resume` / retry, and those are verified by reading.

## Consequences

- The bug class that actually bit us — *mis-classification* — is now covered.
  `DISCONNECTED` falling through to the generic branch, a state collapsing into
  the wrong action, a short write being treated as a failure: all are caught,
  and all were confirmed caught by mutation-testing the suite.
- **Zero cost to shipped code.** No indirection, no test scaffolding in `src/`,
  nothing new in either dist bundle. `playback.cyr` and `capture.cyr` are not in
  the core profile, so the vendored `dist/vani-core.cyr` that cyrius-doom,
  polyomino, bb and mishran embed is untouched.
- **A real residue remains, and is stated rather than papered over**: nothing
  proves the prepare→retry *sequence* is issued correctly, nor that the retry
  happens exactly once. If that sequence regresses, no test fires. This is
  narrower than the original gap but it is not nothing.
- Adding a kernel state to `AlsaPcmState` without extending
  `_vani_recovery_for` lands it in `VANI_RECOVERY_FAIL` — the safe default —
  and `test_recovery_maps_every_state` will flag it.

**Revisit if** the untested residue grows: if recovery gains retry budgets,
backoff, or per-direction policy, the sequence stops being reviewable at a
glance and option 1 becomes worth its cost. Also revisit if vani ever gains a
real-hardware CI leg, which would make the whole question moot.

## Alternatives considered

- **Function-pointer indirection (option 1).** Rejected on cost and blast
  radius. It would put an indirect call on the hot transfer path, and the fn
  pointer is a global that DCE cannot prove unused — a cost paid by every
  consumer, including the four that vendor the core profile into games, to test
  a path none of them can trigger differently. Cyrius has `fnptr` in the include
  chain, so this is buildable; it is simply not worth it here.
- **Compile-time seam (option 2).** Rejected because `cyrius distlib` produces
  the shipped bundle by concatenating `src/`. Test scaffolding in `src/` ships
  to consumers whether or not the flag is set, and CLAUDE.md is explicit about
  not bloating the bundle. It also splits the tested artifact from the shipped
  one, which is the failure mode the distlib drift gate exists to prevent.
- **Do nothing and accept the gap.** Rejected: this is where two of the 1.2.0
  defects lived, and "we cannot test it" had already been the standing answer
  for several releases.

## References

- `src/error.cyr` — `enum VaniRecovery` and `_vani_recovery_for`
- `src/playback.cyr`, `src/capture.cyr` — the classify-then-act split
- `tests/tcyr/vani.tcyr` — the `1.2.2 recovery policy` group
- [`docs/audit/2026-08-20-v1.2.0-audit.md`](../audit/2026-08-20-v1.2.0-audit.md) §7 — the gap this closes
- [ADR 0002](0002-freeze-full-vani-surface-at-1.0.md) — the freeze that rules out reshaping the public transfer API to suit tests
