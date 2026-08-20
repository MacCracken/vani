# Vani Architecture

## Layered model

```
consumer (jalwa, dhvani, …)
    ↓
vani  — single bundled module (lib/vani.cyr)
    ├─ src/alsa.cyr     raw ALSA ioctls (open, hw_params, write/read, drain)
    ├─ src/error.cyr    typed VaniErr + Result helpers
    ├─ src/format.cyr   VaniFormat + frame/byte math
    ├─ src/buffer.cyr   pow-of-2 ring buffer
    ├─ src/device.cyr   VaniDevice (wraps alsa)
    ├─ src/playback.cyr XRUN recovery on write
    ├─ src/capture.cyr  XRUN recovery on read
    └─ src/mixer.cyr    /dev/snd/controlC{N}
    ↓
stdlib syscalls.cyr — open/close/ioctl/read/write
    ↓
Linux ALSA kernel module
```

Vani is the **single audio authority in stdlib** — same model as
mabda for GPU. The raw ALSA ioctl primitives (`audio_*`) live in
`src/alsa.cyr` rather than a separate stdlib `audio.cyr`. This was
absorbed at v0.1.0 (lifted from the prior `cyrius/lib/audio.cyr`);
that legacy path is now retired and gone. Downstream
code that wants ALSA does `include "lib/vani.cyr"` and gets the
entire stack from one bundle.

## ALSA device model

```
/dev/snd/
  controlC0     — card 0 control device (mixer, info)         ← src/mixer.cyr
  pcmC0D0p      — card 0, device 0, playback                  ← src/device.cyr
  pcmC0D0c      — card 0, device 0, capture                   ← src/device.cyr
  pcmC0D1p      — card 0, device 1, playback (HDMI)
```

## Playback flow

```
1. vani_open_playback(card, device)
       → audio_open_playback (alsa.cyr) → open("/dev/snd/pcmCxDxp", O_WRONLY)
2. vani_configure(d, fmt)
       → audio_set_params (alsa.cyr) → store rate / channels / bit_depth
3. vani_prepare(d)
       → ioctl(SNDRV_PCM_IOCTL_PREPARE)
4. vani_play(d, buf, frames)
       → ioctl(SNDRV_PCM_IOCTL_WRITEI_FRAMES)
       → on XRUN: vani_xrun_inc → audio_prepare → retry once
5. vani_drain(d) or vani_drop(d)
       → ioctl DRAIN (wait for tail) / DROP (discard)
6. vani_close(d) → close(fd)
```

All via direct syscalls. No libasound. No middleware.

## Buffer model

```
producer (decoder / synth / mixer)
   ↓ vani_ring_write
RingBuffer  (pow-of-2 bytes, mask-wrap, used / free queries)
   ↓ vani_play_from_ring
audio_write (stdlib) → kernel ALSA buffer → DMA → DAC → speakers
```

Configurable ring buffer size trades latency for reliability:

- 64 ms ring  → safe, no underruns, casual playback
-  5 ms ring  → low latency, pro audio, risk of underrun

`vani_ms_to_frames(fmt, ms)` + `vani_frames_to_bytes(fmt, frames)`
compose to size the ring at a target latency for a given format.

## XRUN recovery

ALSA reports a short / starved write as a negative return; the PCM
state transitions to `SND_PCM_STATE_XRUN`. vani's recovery policy:

The classification is a pure function, `_vani_recovery_for(xfer_result,
state)` in `src/error.cyr`, so it can be tested without a device — see
[ADR 0004](../adr/0004-recovery-policy-seam.md). Both transfer paths
classify through it, then act:

| State | Action | Action constant |
|-------|--------|-----------------|
| XRUN | `audio_prepare` → retry once. Increment xrun_count. | `VANI_RECOVERY_REPREPARE` |
| SUSPENDED | `audio_resume`; if the kernel lacks it, `audio_prepare`. Then retry once. | `VANI_RECOVERY_RESUME` |
| DISCONNECTED | `VANI_ERR_DISCONNECTED`, **no retry** — the device is gone. | `VANI_RECOVERY_GONE` |
| anything else, or a failed STATUS ioctl | `VANI_ERR_WRITE` / `VANI_ERR_READ`. | `VANI_RECOVERY_FAIL` |

The retry count is fixed at 1: if the second transfer also fails, vani
returns `VANI_ERR_UNDERRUN` / `VANI_ERR_OVERRUN` so the caller decides
whether to drop samples or back off.

Two of these rows were wrong for several releases and the errors were
instructive. SUSPENDED was documented as "surface it, resume needs
explicit consent" long after the code had started resuming. DISCONNECTED
had no row at all because `SND_PCM_STATE_DISCONNECTED` was missing from
`AlsaPcmState` — so an unplugged device fell into the XRUN-adjacent
generic branch and was treated as *recoverable*. Both fixed at 1.2.1.

## Mixer

The control device is a separate fd from the PCM stream:
`/dev/snd/controlC{N}`. Volume / mute / source-select are exposed
as numeric "elements" via `SNDRV_CTL_IOCTL_ELEM_*`.

The element ID descriptor and the value union are large structs —
`snd_ctl_elem_id` 64 B, `snd_ctl_elem_info` 272 B, `snd_ctl_elem_value`
1224 B, `snd_ctl_elem_list` 80 B, all pinned by tests against the UAPI
headers. Volume and mute read/write shipped at 0.3.0.

Two properties are load-bearing and easy to get wrong:

- **Every value entry point type-gates first.** `ELEM_READ` and
  `ELEM_WRITE` have no kernel-side type check, so reading an INTEGER
  element as BOOLEAN returns a confident, wrong answer. All four
  accessors issue `ELEM_INFO` and reject the wrong type; `get_mute` was
  the one that did not, until 1.2.0.
- **The element count is bounded before use.** `count` arrives from the
  kernel and drives a `store64` loop into a 1224-byte *stack* buffer.
  It is clamped to the UAPI's `integer.value[128]` extent, and the
  two-pass `ELEM_LIST` clamps the second pass's `used` to what the first
  pass actually allocated — the set can change between the two ioctls.

## yukti integration

```
yukti: "card 0 has PCM playback at /dev/snd/pcmC0D0p,
        supports 44100/48000 Hz, 16/24 bit"
   ↓
vani_open_yukti(desc)
   ↓
vani: open device, vani_configure to the negotiated format
   ↓
(a decoder or synth produces PCM frames)
   ↓
vani_play: write PCM frames
   ↓
speakers: sound
```

`vani_open_yukti` takes the descriptor alone — direction comes from the
descriptor, not a second argument. It was `(desc, direction)` before
0.3.0; that signature appears in older docs and is wrong.

vani never scans for hardware. yukti finds it. vani uses it.


## Distribution profiles

Two bundles come out of `cyrius distlib`, both committed and both
drift-gated in CI (bundles *and* their `.deps` sidecars):

| Profile | File | Contents | Symbols |
|---------|------|----------|---------|
| full | `dist/vani.cyr` | all eight modules — the whole `vani_*` surface | 109 |
| core | `dist/vani-core.cyr` | `src/alsa.cyr` alone — the raw `audio_*` PCM shim | 25 |

The core profile exists because `src/alsa.cyr` is **self-contained by
construction**: zero cross-module references in its source. That is a
property to preserve, not an accident — adding a call from `alsa.cyr`
into any sibling module silently breaks the single-module bundle.

Core omits the `vani_*` device wrapper, ring buffer, capture, mixer,
typed errors and yukti integration. It suits consumers that need only
"open / set_params / write / drain / close" and do not want to pay the
full bundle's parse and codegen cost. Originally driven by the
cyrius-doom proposal at `cyrius-doom/docs/proposals/vani-audio-core-profile.md`.

The `.deps` sidecars record the stdlib leaves each bundle needs; a
consumer's `cyrius deps` reads them. A stale sidecar breaks downstream
builds while both `.cyr` files look fine, which is why the drift gate
covers them.

## The pin is the supply chain

`cyrius build` resolves `include "lib/…"` from
`$CYRIUS_HOME/versions/<pin>/lib` — the version-pinned toolchain
snapshot — **not** from the repo's `./lib/`. The vendored `./lib/` is
editor and IDE support, and the source of the `./lib/ shadows
version-pinned …` warning; nothing else.

Established twice, by experiment: the 1.1.2 audit planted a canary
function in `lib/alloc.cyr` and it never appeared in the binary; the
1.1.4 sweep appended a deliberate **syntax error** to `lib/tagged.cyr`
and the build succeeded, byte-identical.

Two consequences worth internalising:

- Editing `lib/*.cyr` to test a hypothesis does nothing. Change the pin.
- Any A/B that swaps `./lib/` contents measures nothing. Vary
  `cyrius = "X.Y.Z"` in `cyrius.cyml` instead.
