# Bluetooth — `connectivity-bluetooth`

`modules/features/connectivity/bluetooth.nix`. Bluetooth stack plus the
Xbox-controller driver.

## Options

- `connectivity.bluetooth` — plain `mkEnableOption "bluetooth"`.

## What it sets, and why

- `hardware.bluetooth.enable = true`, `powerOnBoot = true` — turn the stack
  on and power it on at boot (a host's controller should be ready without a
  manual toggle).
- `settings.General.Experimental = true` — **required**, because the two
  settings below are experimental features:
  - `FastConnectable = true` — fast reconnect to already-paired devices.
  - `ControllerMode = "dual"` — use both D-Bus and device-root controller
    modes.
  Both are only accepted when `Experimental = true`, so that flag isn't
  stylistic — it gates the other two.
- `settings.Policy.AutoEnable = true` — auto-enable on new pairings.
- `services.blueman.enable = true` — the GUI frontend, for the desktop hosts.
- `hardware.xpadneo.enable = true` — the Xpadneo driver, Linux support for
  Xbox One/Series controllers over Bluetooth (used by the gaming hosts).

## Why the design

The fleet's gaming hosts pair Xbox controllers over Bluetooth, which is why
Xpadneo is bundled here rather than under `gaming` — it's a transport concern
(Bluetooth device support), not a game-launcher one. The `Experimental` +
`FastConnectable` + `ControllerMode="dual"` trio is the specific reason a
controller reconnects quickly instead of re-pairing every boot.
