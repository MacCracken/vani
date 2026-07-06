# 0001 — Pin yukti via `[deps.yukti]` git override ahead of cyrius re-bundle

> **Status**: Superseded — the git override was removed at the 0.9.9
> all-stdlib cut (cyrius ≥ 6.4.3 bundles yukti/patra into stdlib); vani
> now has zero git deps. This ADR is retained as the historical record
> of why the override existed 0.3.0–0.9.8.
> **Date**: 2026-04-30
> **Authors**: Robert MacCracken

## Context

Vani's v0.3.0 multi-device path consumes yukti's audio enumerator
surface (`yukti_audio_devices`, `yukti_audio_card`, `_device`,
`_subdevice`, `_direction`, `_name`, `_driver`, `_hw_id`, `_dev_path`,
`_sys_path`) introduced in yukti 2.2.0 and refined in 2.2.1. At the
time of cut, the cyrius toolchain (5.7.48) still ships yukti 2.1.1
in its bundled `lib/yukti.cyr` — the cyrius-side rebundle is on a
slower cadence than yukti's own release.

The vani roadmap "Handoff" section originally assumed cyrius would
have rebundled yukti before vani's v0.3.0 cut. That ordering didn't
hold; vani is ready before cyrius rolls.

Options on the table:

1. **Wait for the cyrius re-bundle.** Blocks the v0.3.0 cut by an
   unknown amount. The downstream audio consumers (cyrius-doom,
   jalwa, dhvani) are waiting on vani; vani waiting on cyrius
   waiting on yukti compounds the delay.
2. **Vendor yukti 2.2.1 into vani's tree.** Forks the dist; we'd
   carry yukti's bug-fix releases by hand until rebundle. Mabda
   was bitten by a similar shape (lib/ symlinking) — vendoring
   creates the same write-through risk.
3. **`[deps.yukti]` git override pointing at tag `2.2.1`.** The
   cyrius `[deps]` system already supports per-package git+tag
   overrides; mabda uses this pattern for `[deps.samvada]`.
   `cyrius.lock` SHA256-pins the resolved file, and
   `cyrius deps --verify` rejects any drift.

## Decision

Use option 3. Pin yukti via `[deps.yukti] git = "..." tag = "2.2.1"
modules = ["dist/yukti.cyr"]` in `cyrius.cyml`. Remove `yukti` from
the `stdlib = [...]` list to avoid double-resolution. Commit
`cyrius.lock` and add a CI gate that asserts the lock is present
before `cyrius deps` runs (otherwise fresh-clone integrity is zero
— lock would be regenerated trivially).

The override is **temporary**. The matching comment block in
`cyrius.cyml` documents the trigger to remove it: cyrius rebundles
yukti ≥ 2.2.1 in its stdlib. At that point, drop `[deps.yukti]`,
add `yukti` back to `stdlib = [...]`, re-run `cyrius deps`, verify
the lock SHA still matches.

## Consequences

**Enables**:
- v0.3.0 cuts on its own schedule, independent of cyrius rebundle cadence.
- Vani picks up yukti bug-fix releases (e.g. 2.2.1 → 2.2.x) by
  bumping the tag — no cyrius release in between.
- Same pattern available for any future fast-moving sibling
  dependency.

**Constrains**:
- Vani consumers see a slightly larger dep surface (one git URL
  resolves at deps time); first-time `cyrius deps` requires
  network reach to github.com/MacCracken/yukti.
- Adds the LOW-1 finding from the v0.3.0 audit: CI must guard
  `cyrius.lock` presence to prevent fresh-clone supply-chain holes.
  The guard is one shell line in
  [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).

**Reversal trigger**: cyrius rebundles yukti ≥ 2.2.1 in its
stdlib. The fold-in plan in
[`docs/development/cyrius-stdlib-fold-in.md`](../development/cyrius-stdlib-fold-in.md)
is independent of this decision (it's about retiring
`cyrius/lib/audio.cyr`, not yukti) — so reversal is a small
isolated diff.

## Alternatives considered

- **Wait for the cyrius re-bundle.** Lost: blocks downstream
  consumers on a release cadence vani doesn't control.
- **Vendor yukti 2.2.1 into vani's tree.** Lost: write-through risk
  (mabda's lib/ symlink incident); manual maintenance burden for
  upstream bug-fix releases.

## References

- `cyrius.cyml` — the `[deps.yukti]` block and its inline comment
  documenting the rebundle removal trigger.
- [`cyrius.lock`](../../cyrius.lock) — SHA256 anchors for the
  resolved files.
- [`docs/audit/2026-04-30-v0.3.0-audit.md`](../audit/2026-04-30-v0.3.0-audit.md)
  — LOW-1 finding (CI lock-file presence guard).
- Mabda's `[deps.samvada]` block — the precedent for per-package
  git overrides in AGNOS libraries.
