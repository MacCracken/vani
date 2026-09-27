# 002 — `cyrius distlib` counts words in comments when it writes a profile's `.deps`

The `.deps` sidecar next to each bundle lists the stdlib modules a
consumer's `cyrius deps` must pull in. For a **profile** bundle
(`[lib.<profile>]` — vani's `core`), `cyrius distlib` starts from the
fold's whole stdlib leaf list and keeps a leaf only if the bundle
"references" it: if any top-level `fn` or `var` the leaf declares appears
as a whole word **anywhere in the bundle text**. The scan is plain text,
so comments and string literals count. A comment can add a dependency no
line of code has.

(cyrius `cbt/commands.cyr`: `_distlib_prune_profile_leaves` →
`_distlib_leaf_referenced_d` → `_distlib_bundle_refs`, added at v6.4.48.
The modules a kept leaf needs come along with it, which is how one word
brought in four.)

## How it was found

2026-09-26, cyrius 6.6.2, while adding `_audio_open_pcm` to
`src/alsa.cyr` — the only module in the core profile. After the change,
`dist/vani-core.deps` went from 3 leaves (`syscalls`, `string`, `alloc`)
to 8 (`+ io`, `process`, `fmt`, `vec`, `str`). Bisected on a scratch copy:

- `O_WRONLY` / `O_RDONLY` match `var O_WRONLY` / `var O_RDONLY` in
  `lib/io.cyr` (its portable spellings; the syscalls peer's `OpenFlag`
  enum members do not count, because enum members are not scanned). They
  kept `io` whether written in code or only in comments: making the code a
  literal was not enough while a comment still said `O_WRONLY`.
- The English word **"run"**, in a comment ("before any PREPARE can run"),
  matches `fn run` in `lib/process.cyr`. That kept `process`, and with it
  `vec`, `str` and `fmt`.

Rewording those comments put the sidecar back to exactly the 3 leaves it
had. `O_NONBLOCK` and `SYS_FCNTL` are enum members of the syscalls peer,
already a leaf, so they cost nothing.

## Consequences

- Words in `src/alsa.cyr` comments are part of the core profile's
  dependency surface. Four game consumers vendor that bundle; one stray
  word cost each of them five extra stdlib modules on the next re-vendor.
- **The CI drift gate does not catch this.** It checks that the committed
  sidecar matches a fresh `cyrius distlib`, so a comment edit committed
  with its regenerated sidecar passes. When `dist/vani-core.deps` changes
  in a diff, read it: it should say `syscalls`, `string`, `alloc`.
- To check a word, look for a top-level declaration of it in the pinned
  snapshot: `grep -nE '^(fn|var) +WORD\b' ~/.cyrius/versions/<pin>/lib/*.cyr`
  (substitute the word). A hit in a module other than the three leaves
  means the word will keep that module.
- The full profile (`dist/vani.deps`, 21 leaves) is not pruned this way,
  so the effect is invisible there. It matters for core.

## Upstream

Filed 2026-09-26 as cyrius
`docs/development/issues/2026-09-26-vani-distlib-profile-deps-counts-comments-and-strings-as-references.md`
(string literals count too — verified). If `_distlib_bundle_refs` learns
to skip `#` comments and string literals, this note becomes history and
the constraint on `src/alsa.cyr` comments lifts.

## References

- `src/alsa.cyr` — the `_audio_open_pcm` comment, which says why the
  access modes there are literals
- [`overview.md`](overview.md) § Distribution profiles — what the sidecars are for
- [001](001-pcm-open-nonblock.md) — the change that surfaced this
