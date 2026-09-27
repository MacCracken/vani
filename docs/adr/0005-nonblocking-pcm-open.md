# 0005 — Open PCM nodes `O_NONBLOCK`, then clear it before the first PREPARE

> **Status**: Accepted
> **Date**: 2026-09-26
> **Authors**: Robert MacCracken

## Context

`audio_open_playback` / `audio_open_capture` opened `/dev/snd/pcmC*D*{p,c}`
blocking. The kernel answers a blocking open of a **busy** PCM — every
subdevice held — by sleeping until the holder closes it. The ALC897 analog
PCM on the dev box has one subdevice, and PipeWire / wireplumber hold it
whenever they have a stream, so the hang is ordinary rather than exotic:
every core-profile consumer (cyrius-doom, polyomino, bb, mishran) could
freeze at startup instead of degrading to silent. Reproduced on hardware
2026-09-26 — [architecture note 001](../architecture/001-pcm-open-nonblock.md)
has the kernel paths and the measurements.

The open has to fail fast without changing what consumers get afterwards:
every one of them treats `audio_write` as blocking, and `audio_drain` as
waiting for the tail.

Three shapes were on the table:

1. **Probe, then open.** Open the node `O_NONBLOCK`, close it, and on
   success do the old blocking open. cyrius-polyomino shipped this in its
   own code (`audio_probe_playback`) because it could not edit its vendored
   vani.
2. **Open `O_NONBLOCK`, clear it with `F_SETFL`.** One open; the busy
   check is the open itself.
3. **Stay non-blocking and emulate blocking in vani.** Keep `O_NONBLOCK`,
   and have `audio_write` / `audio_read` / `audio_drain` `poll()` and retry
   on `-EAGAIN`.

Option 2 had an open question the kernel source answers and the hardware
confirmed: `fcntl(F_SETFL)` changes only `file->f_flags`, while the transfer
path reads a copy the PCM core takes at open **and again at every
PREPARE**. Cleared before the first PREPARE, the handle behaves exactly
like a blocking open; cleared after one, writes stay non-blocking until the
next.

## Decision

**`_audio_open_pcm` in `src/alsa.cyr` opens the node with `O_NONBLOCK` —
so a busy PCM returns `-EBUSY` at once and the open returns 0 — and clears
`O_NONBLOCK` with `F_GETFL` / `F_SETFL` before handing the descriptor back.
If the clear fails, the descriptor is closed and the open fails.** The agnos
arms (`sys_snd_open`) are untouched.

## Consequences

- **No startup hang.** A busy PCM costs microseconds (measured 4-71 µs)
  and yields the documented null handle, which every consumer already
  treats as "run silent".
- **No behaviour change on a free PCM.** Writes, reads and DRAIN block as
  before, including after XRUN → PREPARE recovery — verified on hardware,
  case by case, in note 001.
- **No race.** The busy check and the claim of the subdevice are the same
  syscall.
- **It leans on a kernel behaviour**: the copy of `f_flags` refreshed at
  PREPARE. That has been in mainline since at least 2.6.20, and alsa-lib's
  `snd_pcm_nonblock()` and JACK2's startup sequence depend on the same
  thing — but it is kernel internals, not UAPI. `programs/busy_open.cyr`
  is the check that would catch a change; run it when the dev box kernel
  moves.
- **The clear must stay inside the open.** Moving it later (into
  `audio_prepare`, or after `audio_set_params*`) silently turns writes
  non-blocking. Note 001 states this as the invariant.
- Two extra `fcntl` syscalls per open. Opens are rare; nothing to measure.
- Polyomino's probe becomes redundant once it re-vendors a vani with this
  change, and the race its own CHANGELOG accepts goes away with it.

**Revisit if** a kernel stops refreshing `substream->f_flags` at PREPARE
(`busy_open` fails its "blocked for it" checks while "fd is blocking"
passes) — fall back to option 1 and accept its race. Or if vani ever wants
genuinely non-blocking transfers on Linux, in which case option 3's
machinery becomes a feature rather than an emulation.

## Alternatives considered

- **Probe, then open (option 1).** Leaves a race: another process that
  grabs the device between the probe's close and the real open puts that
  open back to sleep, which is the bug. It also opens and closes the
  device twice per open, and each open and close runs the driver's
  callbacks. It was the fallback if option 2 had failed on hardware; it
  did not.
- **Emulate blocking with `poll()` (option 3).** Moves the wait loop out
  of the kernel and into every transfer path — the hot path, the XRUN
  interaction, `-EINTR` handling and DRAIN's own non-blocking return — to
  solve a problem that exists only at open. It is also the bigger change
  to code four games vendor. Rejected on size and risk.
- **Status quo (blocking open).** The hang. Rejected.

## References

- `src/alsa.cyr` — `_audio_open_pcm`, `audio_open_playback`, `audio_open_capture`
- [Architecture note 001](../architecture/001-pcm-open-nonblock.md) — kernel paths, measurements, the invariant, the tests
- `programs/busy_open.cyr` — the real-hardware check; `tests/tcyr/vani.tcyr` group `busy PCM open` — the CPU check
- cyrius-polyomino `src/audio.cyr` (`audio_probe_playback`) and its CHANGELOG `[Unreleased]` — option 1 in the wild
