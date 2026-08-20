# Architecture Decision Records

Each ADR captures a decision that wasn't obvious from the code alone —
*why this option over the others*, what trade-offs were accepted, and
under what conditions it should be revisited.

## Convention

- File naming: `NNNN-short-title.md` (zero-padded 4-digit index, kebab-case).
- **Never renumber.** Once an ADR has a number, it keeps that number forever.
- New ADRs land at the next free index.
- Superseded ADRs stay in the directory; their `Status` updates to
  `Superseded by NNNN`. Don't delete them — the historical record is the point.
- Use [`template.md`](template.md) as the starting point for new ADRs.

## When to write an ADR

- Choosing between competing approaches with material trade-offs
- Adopting or rejecting a dependency (especially git-pinned overrides)
- Changing the public API in a non-trivial way
- Picking a performance trade-off that constrains future choices
- Setting a process invariant that's not derivable from the code

If the answer to "why this and not the other thing?" would surprise a
new contributor reading the diff, write an ADR.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](0001-yukti-git-override.md) | Yukti dep pinned via git override ahead of cyrius re-bundle | Accepted |
| [0002](0002-freeze-full-vani-surface-at-1.0.md) | Freeze the full `vani_*` surface at 1.0.0 | Accepted |
| [0003](0003-no-windows-pe-target.md) | Windows/PE is not a supported vani target | Accepted |
| [0004](0004-recovery-policy-seam.md) | Split recovery policy from transport; decline a mockable ioctl seam | Accepted |
