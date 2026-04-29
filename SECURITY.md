# Security Policy

## Scope

Vani opens audio devices via ALSA ioctls. Attack surface: malformed device paths, ioctl parameter injection, buffer overflows in PCM write/read paths. All buffer sizes must be bounds-checked.

## Reporting

Report vulnerabilities to robert.maccracken@gmail.com.
