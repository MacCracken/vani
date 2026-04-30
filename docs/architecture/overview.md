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
that legacy path retires at cyrius 5.8.0. After 5.8.0, downstream
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

| State | Action |
|-------|--------|
| XRUN | `audio_prepare` → retry the same write/read once. Increment xrun_count. |
| SUSPENDED | Surface as `VANI_ERR_SUSPENDED` — resume needs explicit consent. |
| anything else | Surface as `VANI_ERR_WRITE` / `VANI_ERR_READ`. |

The retry count is fixed at 1: if the second write also fails, we
return `VANI_ERR_UNDERRUN` so the caller decides whether to drop
samples or back off.

## Mixer

The control device is a separate fd from the PCM stream:
`/dev/snd/controlC{N}`. Volume / mute / source-select are exposed
as numeric "elements" via `SNDRV_CTL_IOCTL_ELEM_*`.

The element ID descriptor and the value union are large structs
(200+ bytes); v0.1.0 ships the open/close lifecycle and ioctl
number table, with the per-element struct packing landing in v0.3.0
once the wire layout is locked in tests against real hardware.

## yukti integration

```
yukti: "card 0 has PCM playback at /dev/snd/pcmC0D0p,
        supports 44100/48000 Hz, 16/24 bit"
   ↓
vani_open_yukti(desc, VANI_PLAYBACK)
   ↓
vani: open device, vani_configure to negotiated format
   ↓
shravan: decode FLAC → PCM samples
   ↓
vani_play: write PCM frames
   ↓
speakers: sound
```

vani never scans for hardware. yukti finds it. vani uses it.
