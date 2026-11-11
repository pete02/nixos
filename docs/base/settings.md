# Base settings — `base-settings`

`modules/features/base/settings.nix`. The always-on core of every machine:
there is no `base.enable`, this module's `config` is unconditional.

## Identity options other modules depend on

It declares exactly two options, and they are load-bearing across the whole
flake:

- `username` — the main user. `mkHost` injects `{ inherit hostname; }` into
  every host's module list (see [hosts](../fleet/lib/hosts.md)), and modules
  like `rpcs3-savegames` (`User = config.username`) or the shell services read
  it. Host configs set it once (`username = "pete";`).
- `hostname` — feeds `networking.hostName = config.hostname;` and, through the
  same `mkHost` tail module, the `ssh.server.enable` / `nixbuilder.buildServer`
  defaults keyed by host name.

Declaring them here (rather than each host setting `networking.hostName`
directly) is what lets the fleet library and the host-table logic talk about
"the host" uniformly.

## The user

`users.users.${config.username}` is a normal user in four extra groups, each
for a specific reason:

- `wheel` — sudo / `@wheel` trusted-users in the installer.
- `seat` — the seatd daemon's group; Wayland compositors (Hyprland, cage) need
  seat access to take the session leader seat. Cross-link: the shells modules
  assume this.
- `dialout` — raw device access (serial / USB tools).
- `uucp` — same family, older Unix device group.

## Locale, deliberately Finnish

- `console.keyMap = "fi"` — the TTY keyboard is Finnish; the installer's
  `_settings.nix` keeps its own `locale` knob separate (installer is a
  different, keyboard-less context).
- `time.timeZone = "Europe/Helsinki"` — the fleet's physical timezone.
- `i18n.defaultLocale = "fi_FI.UTF-8"` — UTF-8 with Finnish collation.

These are set here so no host config repeats them; the values are a
geographic/human choice, not a per-machine one.

## Nix defaults

- `experimental-features = [nix-command, flakes]` — needed to use the flake
  itself at all; set globally so `nixos-rebuild`/`nix eval` work without
  per-invocation flags.
- `nix.gc.automatic` daily, `--delete-older-than 7d` — keeps the store bounded
  on machines that build (aria/raysha are build servers).
- `auto-optimise-store = true` — dedupe identical store paths to hardlinks,
  saving space on the same long-lived stores.
- `nixpkgs.config.allowUnfree = true` — required so `steam`, `rpcs3`, and the
  NVIDIA blobs resolve at all. Cross-link: the gaming and hardware leaves that
  pull those packages.

## Small package set

`vim git tree groff htop unzip unrar lshw libnotify fastfetch` — a baseline
toolkit so a freshly-installed machine is usable before any feature module
turns anything on. `libnotify` pairs with the ntfy notification pattern used
by healthcheck/nixos-management (they `curl` instead, but the notifier habit
is the fleet's).
