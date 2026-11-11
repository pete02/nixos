# Installer images — how each one is built

Leaf doc. Three `flake.nixosConfigurations` in `modules/installer/default.nix`,
each assembled from the `_`-prefixed pieces.

## The shared base

`_base.nix` is imported by all three images and layers in what a running
installer needs:

- `self.nixosModules.nixbuilder` + `self.nixosModules.sops` — so an installer
  image can *push to the cache* and read secrets the same way the fleet does.
  `nixbuilder.cache.client.enable = true` points it at the Attic cache
  ([fleet constants](fleet/lib/fleet.md)).
- `experimental-features`, `trusted-users = ["root" "@wheel"]` — the installer
  runs `nix` commands as the live user.
- Time zone, locale, `stateVersion` come from `settings` — see below.
- `openssh.PermitRootLogin = "no"`;
  `PasswordAuthentication = settings.sshKeys == []` — password auth is only on
  when *no* keys were configured, i.e. it's a fallback, not a default.
- The live user gets `wheel` + `authorizedKeys` from `settings.sshKeys`.

## `settings` — the knobs

`default.nix` pulls `settings = import ./_settings.nix` — a **plain import, not
a flake part**, because it's data consumed by the modules, not a module itself.
It holds: username, `sshKeys` (raysha's public key — the key the fleet's other
machines present when sshing in), timeZone, locale, stateVersion, and
`initialPassword` (**value deliberately not reproduced here** — it's a
bootstrap-only login password, marked `# change me` in the file).

## Per-target overlays (`_hosts/`)

- `x86.nix` — hostName `x86`, systemd-boot + EFI. Before a real disk exists,
  `hasHw = builtins.pathExists ../_hardware/x86.nix` gates the generated
  hardware config; until `nixos-installer install` writes that file, the config
  falls back to by-label fileSystems (`nixos`, `NIXOS_BOOT`) "so the config
  still evaluates".
- `iso-x86.nix` — imports nixpkgs `installation-cd-minimal`, forces the ISO
  name, adds the `installer` package to systemPackages ("# The wrapper embeds
  this whole flake's source, so it ships on the ISO."), plus gptfdisk/parted/vim.
- `rpi3.nix` — nixpkgs `sd-image-aarch64` + `_base`; redistributable firmware,
  zram swap.
- `rpi5.nix` — `nixos-raspberrypi` modules (`raspberry-pi-5.base`,
  `display-vc4`, `sd-image`) + `_base`; hostName is **`alanna`**, not `rpi5` —
  the Pi 5 image boots straight into alanna's identity. It also forces
  `PasswordAuthentication = true` and `initialPassword`: a Pi has no keyboard
  at boot, so a password login is the only way in.

## The generated half (`_hardware/`)

`_hardware/x86.nix` is *written by the install tool* (`nixos-generate-config
--show-hardware-config` redirected into it) and then read back by
`x86.nix`'s `hasHw` gate. That's why it lives under the installer, not under
`modules/hosts/` — the host configs stay hand-written
([hosts docs](hosts.md)); only the installer's target carries generated disk
info.
