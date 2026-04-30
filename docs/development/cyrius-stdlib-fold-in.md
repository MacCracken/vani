# Cyrius stdlib fold-in plan — target: cyrius 5.8.0

## Goal

Ship `vani` as the canonical audio library in the Cyrius standard
library distribution, mirroring how `mabda` is the canonical GPU
library. After 5.8.0, downstream code that wants ALSA PCM does:

```cyrius
include "lib/vani.cyr"
```

…and gets the full stack — raw `audio_*` ioctls plus the higher-level
`vani_*` abstractions (typed errors, ring buffer, XRUN recovery,
mixer, yukti adapter) — from a single bundled module.

## Why

Two reasons.

1. **Single authority per domain.** Mabda owns wgpu_ffi /
   wgpu_types / wgpu_descriptors directly under `src/`; there is no
   separate "raw wgpu" sublayer in stdlib that mabda wraps. Yukti
   owns its raw `/dev` scanning the same way. Up through cyrius
   v5.7.x, `audio.cyr` was the lone exception — a low-level audio
   primitive sitting in stdlib with no high-level peer. v5.8.0
   closes that gap.

2. **One include, full stack.** Today a consumer that wants to play
   a tone has to learn two surfaces (stdlib `audio.cyr` for the
   ioctls and `vani` for everything above). After 5.8.0 it's just
   `lib/vani.cyr`.

## Migration done in vani v0.1.0

- [x] Lift `cyrius/lib/audio.cyr` (236 LOC) → `vani/src/alsa.cyr`
- [x] Drop `"audio"` from `[deps].stdlib` in `cyrius.cyml`
- [x] Add `"src/alsa.cyr"` first in `[lib].modules`
- [x] Update `src/lib.cyr` include chain (drop `lib/audio.cyr`,
      add `src/alsa.cyr` first in domain order)
- [x] Fix two-byte stack array bug (`var xferi[2]` → `var xferi[16]`)
      in `audio_write` / `audio_read` carried over from upstream
- [x] CHANGELOG entry calling out the absorb + bug fix

## Migration to do in cyrius 5.8.0

In the `cyrius` repo (separate PR — user owns the timing):

1. Add `[deps.vani]` to `cyrius/cyrius.cyml`:
   ```toml
   [deps.vani]
   git = "https://github.com/MacCracken/vani.git"
   tag = "0.1.0"  # or whatever vani ships at 5.8.0 cut time
   modules = ["dist/vani.cyr"]
   ```
2. Delete `cyrius/lib/audio.cyr` — `dist/vani.cyr` provides the
   same `audio_*` symbol set bundled inline.
3. Update `cyrius/CHANGELOG.md` 5.8.0 entry: "audio.cyr retired —
   ALSA PCM now lives in vani; consumers replace `include
   "lib/audio.cyr"` with `include "lib/vani.cyr"`."
4. Cyrius release workflow already pulls `[deps.NAME]` modules into
   the install tree — no scripts/install.sh changes needed.
5. Run cyrius's full test suite to confirm nothing else in the
   ecosystem was importing `lib/audio.cyr` directly. (Quick check:
   `grep -rn 'lib/audio.cyr' /home/macro/Repos`.)

## Downstream impact

The `audio_*` API surface is **byte-for-byte stable**. Anyone who
had `include "lib/audio.cyr"` flips to `include "lib/vani.cyr"` and
keeps every existing call site. They additionally get the `vani_*`
higher-level API for free.

Searched the local AGNOS tree at vani v0.1.0 cut time
(`cyrius/`, `mabda/`, `vidya/`, `vani/`): no in-tree consumer
imports `lib/audio.cyr`. The only known caller was vani's prior
scaffold, which is now gone.

## Vani-side prerequisites for 5.8.0 fold-in

- [ ] vani test suite at 100 % pass on the absorb (current: 62 / 62)
- [ ] vani v0.2.0 — full `SNDRV_PCM_IOCTL_HW_PARAMS` (608 B)
      negotiation. Optional for fold-in but ideal so 5.8.0 ships a
      vani that can actually negotiate, not just store params.
- [ ] vani real-hardware integration test passing on at least
      onboard audio — gives 5.8.0 a credible "yes this works"
      story.
- [ ] Tag a vani release the cyrius `[deps.vani]` block can pin to.

If 5.8.0 ships before vani v0.2.0 lands, the fold-in still works:
`audio_set_params` is the simplified path it has always been, and
v0.2.0 lands as a vani patch release that consumers pick up by
bumping the tag in `cyrius/cyrius.cyml`.
