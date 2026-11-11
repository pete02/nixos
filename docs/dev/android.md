# Dev Android — `dev-android`

`modules/features/dev/android.nix`. Minimal Android-device access.

## Options

- `dev.android` — enable the Android development environment.

## What it sets, and why

- `services.udev.packages = [android-tools]` — installs the udev rules that
  let the kernel recognise Android phones over USB (permissions/perms rules).
- `users.users.<user>.extraGroups = ["adbusers"]` — puts the user in the
  `adbusers` group so `adb` can talk to the device without sudo.

## Why the design

Both pieces are mandatory as a pair: the udev rules give the device nodes the
right ownership, and the `adbusers` group is what the rules' permission model
grants access to. Enabling one without the other yields either an
unrecognised device or a permission-denied `adb` — so they live together in one
switch.
