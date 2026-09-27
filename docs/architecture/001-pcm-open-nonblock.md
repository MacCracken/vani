# 001 — A busy PCM puts a blocking open to sleep; transfers read `O_NONBLOCK` as of the last PREPARE

Two kernel behaviours, one invariant. Neither can be derived from vani's
code, and getting either wrong fails silently: a hang at startup, or a
"blocking" write that returns a quarter of what it was given.

## 1. A busy PCM makes a blocking open sleep

`snd_pcm_open` (`sound/core/pcm_native.c`) tries to attach a free
substream. When every substream (subdevice) is already attached, it gets
`-EAGAIN` and then:

- **with `O_NONBLOCK`** returns `-EBUSY` at once;
- **without it** sleeps `TASK_INTERRUPTIBLE` on `pcm->open_wait` until a
  holder closes, the card shuts down, or a signal arrives.

On this dev box, card 1's ALC897 analog PCM has **one** subdevice
(`/proc/asound/card1/pcm0p/info`: `subdevices_count: 1`), so any holder
makes it busy: PipeWire / wireplumber (which get the device ACL along with
the seat session) or another app. Half-duplex devices also answer `-EAGAIN`
when the *opposite* direction is busy, and the same sleep follows.

Through 1.2.5 `audio_open_playback` / `audio_open_capture` opened plain
blocking, so every core-profile consumer (cyrius-doom, polyomino, bb,
mishran) could hang at startup instead of running silent. Reproduced
2026-09-26 on kernel 7.2.6: with a second process holding
`/dev/snd/pcmC1D0p`, the 1.2.5 `audio_open_playback(1, 0)` was still asleep
when `timeout 5` killed it (exit 124); the fixed one returned 0 in 71 µs.

## 2. Transfers read `O_NONBLOCK` from a copy taken at open and at every PREPARE

`fcntl(F_SETFL)` changes only `file->f_flags`. The PCM core keeps its own
copy, and the transfer path reads the copy:

| Kernel site | What it does with the flags |
|-------------|-----------------------------|
| `snd_pcm_attach_substream` (`pcm.c`) | `substream->f_flags = file->f_flags` — the copy taken at open |
| `snd_pcm_prepare` → `snd_pcm_pre_prepare` (`pcm_native.c`) | `substream->f_flags = file->f_flags` — **refreshed on every PREPARE** |
| `__snd_pcm_lib_xfer` (`pcm_lib.c`) — WRITEI, READI, `write(2)`, `read(2)` | `nonblock = substream->f_flags & O_NONBLOCK` — reads the **copy** |
| `snd_pcm_drain` (`pcm_native.c`) | reads the **live** `file->f_flags` |

So a descriptor opened `O_NONBLOCK` whose flag is cleared with `F_SETFL`
**before its first PREPARE** is indistinguishable from one opened
blocking: open → HW_PARAMS → PREPARE → transfers. Clear it *after* a
PREPARE and the writes stay non-blocking until the next PREPARE, while
DRAIN already blocks.

A transfer is only possible in PREPARED / RUNNING / PAUSED, and every path
into those states goes through a PREPARE (`audio_prepare`, `vani_prepare`,
and XRUN recovery's re-prepare), so clearing the flag inside the open
covers every transfer the handle will ever make.

The copy-at-PREPARE is old and stable: present in the mainline source at
v2.6.20 (2007), v4.4, v4.19, v6.1, v6.6 and 7.3-rc4. alsa-lib's
`snd_pcm_nonblock()` on a `hw` PCM is nothing but this `F_GETFL` /
`F_SETFL` toggle (`src/pcm/pcm_hw.c`, `snd_pcm_hw_nonblock`). JACK2 uses
the same idiom as vani, for the same reason: `snd_pcm_open(...,
SND_PCM_NONBLOCK)`, report `EBUSY` as "already in use", then
`snd_pcm_nonblock(handle, 0)` before it sets parameters
(`linux/alsa/alsa_driver.c`).

### Measured

2026-09-26, card 1 ALC897 analog (one subdevice), kernel 7.2.6,
48 kHz S16_LE stereo, period 1024, buffer 4096 frames. Each case writes
16384 zero frames (4× the ring) twice, then DRAINs. A blocking write takes
(16384 − 4096) / 48000 ≈ 256 ms; DRAIN of a full ring ≈ 85 ms.

| # | Open | `F_SETFL` clears `O_NONBLOCK`… | write #1 | write #2 | DRAIN |
|---|------|------------------------------|----------|----------|-------|
| 0 | blocking | — | 16384 in 256 ms | 16384 in 341 ms | 0 in 85 ms |
| 1 | `O_NONBLOCK` | never | **4096 in 0 ms** | **1 in 0 ms** | **−11 (EAGAIN) in 0 ms** |
| 2 | `O_NONBLOCK` | before HW_PARAMS | 16384 in 256 ms | 16384 in 341 ms | 0 in 85 ms |
| 3 | `O_NONBLOCK` | after PREPARE | **4096 in 0 ms** | **−11 in 0 ms** | 0 in 85 ms |
| 4 | `O_NONBLOCK` | after HW_PARAMS, before PREPARE | 16384 in 256 ms | 16384 in 341 ms | 0 in 85 ms |
| 5 | `O_NONBLOCK` | after PREPARE, then PREPARE again | 16384 in 256 ms | 16384 in 341 ms | 0 in 85 ms |
| 6 | `O_NONBLOCK` | right after open (vani's shape); then XRUN → −EPIPE → PREPARE | 16384 in 256 ms | 16384 in 341 ms | 0 in 85 ms |

Case 4 against case 3 pins the refresh to PREPARE, not HW_PARAMS; case 5
shows a later PREPARE picks the change up; case 6 is exactly what vani
does, including the recovery path consumers take after an underrun.

## The invariant

**`_audio_open_pcm` (`src/alsa.cyr`) opens with `O_NONBLOCK` and clears it
before it returns.** Both halves are load-bearing:

- Do not "simplify" it back to a blocking open — that is the hang.
- Do not move the clear later (into `audio_prepare`, or after
  `audio_set_params*`): after a PREPARE it no longer reaches the writes.
- If the clear fails the helper closes the fd and fails the open. A handle
  that silently delivers short writes and `-EAGAIN` is worse than no
  handle; no consumer handles either.

A consumer that sets `O_NONBLOCK` on vani's fd itself (via `audio_fd`)
gets non-blocking transfers from its next PREPARE on. That is the kernel's
contract, not vani's, and vani does not guard against it.

## How it is tested

- **CPU suite** (`tests/tcyr/vani.tcyr`, group `busy PCM open`): drives
  `_audio_open_pcm` against a **named FIFO**, whose open has the same shape
  — with no reader, a blocking `O_WRONLY` open sleeps, and `O_NONBLOCK`
  fails at once (`-ENXIO`). It must be a named FIFO: `fifo_open` skips that
  `-ENXIO` for an anonymous pipe reopened through `/proc/self/fd`, so a
  `pipe()` stand-in opens fine and proves nothing. A SIGALRM watchdog turns
  a regression to a sleeping open into a failure instead of a hung suite.
  The suite also checks the returned fd has `O_NONBLOCK` clear and the
  access mode intact.
- **Real hardware** (`programs/busy_open.cyr` → `build/vani_busy_open`,
  silent): holds every subdevice itself, checks both opens return 0 at
  once, then releases them and checks the kernel half — a 4×-ring WRITEI
  that blocks for all of it, a DRAIN that waits, both again after XRUN →
  PREPARE, and a 100 ms READI that blocks. Only this can catch a kernel
  that stopped refreshing the copy at PREPARE.

Both were validated with negative controls: reverting to a blocking open
kills the suite and the program on their watchdogs (exit 142, SIGALRM);
dropping the `F_SETFL` clear fails the fd assertions and, on hardware,
ten checks (the 4×-ring write returns 4096 at once, DRAIN returns
`-EAGAIN`).

## References

- `src/alsa.cyr` — `_audio_open_pcm`, `audio_open_playback`, `audio_open_capture`
- [ADR 0005](../adr/0005-nonblocking-pcm-open.md) — why this and not a probe-then-open
- Linux `sound/core/pcm_native.c` (`snd_pcm_open`, `snd_pcm_pre_prepare`, `snd_pcm_prepare`, `snd_pcm_drain`), `sound/core/pcm.c` (`snd_pcm_attach_substream`), `sound/core/pcm_lib.c` (`__snd_pcm_lib_xfer`)
- alsa-lib `src/pcm/pcm_hw.c` (`snd_pcm_hw_nonblock`); JACK2 `linux/alsa/alsa_driver.c`
- cyrius-polyomino `src/audio.cyr` `audio_probe_playback` — the consumer-side workaround this makes unnecessary
