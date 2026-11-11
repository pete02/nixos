# Peripherals — `hardware-peripherals`

`modules/features/hardware/peripherals.nix`. Options
`peripherals.logitech` and `peripherals.razer` (note: top-level namespace,
not `hardware.*`).

## What it sets, and why

- Logitech support: `logiops` (Logitech's own options engine for MX-master
  style mice), `piper` and `libratbag` (the GUI + daemon frontend for
  mouse configuration), `services.ratbagd.enable` (the daemon actually
  programming mice), and `hardware.logitech.wireless.enable` — the
  `logitech_background`/LNX daemon for wireless feature keys, separate
  from the mouse tools because Samba-and-mouse config travel through
  different daemons.
- Razer support: `openrazer-daemon` + `polychromatic` (daemon + GTK
  frontend for RGB), and adds the current user to the `openrazer` group —
  openrazer talks to the hardware through a group-permitted device path,
  so membership is the requirement, not permissions set at install time.

## Why the design

Vendor-split opt-ins, each self-contained: a host enables the brand it
owns. Mouse *programming* (ratbagd) and wireless *features*
(logitech.wireless) are separate NixOS knobs that both belong to the
Logitech option, so the module merges them behind one switch.
