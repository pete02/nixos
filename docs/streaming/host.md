# Host-side Sunshine (`streaming.sunshine`)

Module: `modules/features/streaming/host-streaming.nix` (attr `streaming-sunshine`).

## What it does when enabled

- `services.sunshine`: `capture = "kms"`, `encoder = "nvenc"`, `hevc_mode = 3`, `capSysAdmin = true`, firewall opened.
- User service wired to `graphical-session.target` (Sunshine runs inside the desktop session).
- `hardware.uinput.enable` + adds the `uinput` group to `config.username`'s supplementary groups (keyboard/mouse streaming via `/dev/uinput`).

## The `desktop` option

`streaming.sunshine.desktop` (string, default `"gaming"`) names a desktop def in the separate `desktops` module (`config.desktops.<name>`). That def — not this module — supplies everything Hyprland-coupled:

- EDID/monitor handling (`philips.edid`, `drm.edid_firmware`, `video=` kernelParams),
- the csrf origin for the Sunshine web UI (`https://<ip>:47990`),
- the start/stop/launch wrapper scripts.

This is why the sunshine module stayed shell-agnostic: nothing here hardcodes monitor names, IPs, or wrapper scripts anymore. If the `desktops` module is not activated, `streaming.sunshine.desktop` is simply unused by this module (the def's pieces must then be provided by the host's own config).

## Host usage

`raysha` sets `streaming.sunshine.enable = true` (plus its monitor overlay in `_desktops.nix`).
