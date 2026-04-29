# Vani Architecture

## ALSA Device Model

```
/dev/snd/
  controlC0     — card 0 control (mixer, info)
  pcmC0D0p      — card 0, device 0, playback
  pcmC0D0c      — card 0, device 0, capture
  pcmC0D1p      — card 0, device 1, playback (HDMI)
```

## ALSA ioctl Flow

```
1. open("/dev/snd/pcmC0D0p", O_RDWR)
2. ioctl(SNDRV_PCM_IOCTL_HW_PARAMS)    — set format, rate, channels, buffer size
3. ioctl(SNDRV_PCM_IOCTL_SW_PARAMS)    — set start threshold, stop threshold
4. ioctl(SNDRV_PCM_IOCTL_PREPARE)      — prepare device
5. write(fd, pcm_data, frames)          — write PCM samples
6. ioctl(SNDRV_PCM_IOCTL_DRAIN)        — wait for playback to finish
7. close(fd)
```

All via direct syscalls. No libasound. No middleware.

## Buffer Model

```
Application buffer (vani ring buffer)
  → write() to kernel ALSA buffer
    → DMA to sound hardware
      → DAC → speakers → air
```

Configurable buffer size trades latency for reliability:
- Large buffer (64ms): safe, no underruns, casual playback
- Small buffer (5ms): low latency, pro audio, risk of underrun

## Integration

```
yukti: "card 0 has PCM playback at /dev/snd/pcmC0D0p, supports 44100/48000 Hz, 16/24 bit"
  ↓
vani: open device, negotiate 48000 Hz 16-bit stereo
  ↓
shravan: decode FLAC → PCM samples
  ↓
vani: write PCM to device
  ↓
speakers: sound
```
