# Containerised streaming desktops (`streaming.desktops`)

Module: `modules/features/streaming/podman-streaming.nix` (attr `streaming-desktops`).

One podman container per desktop entry; each container runs a headless Hyprland compositor and one Sunshine instance per virtual output, streaming to a Moonlight client on another device (a TV, a box). The desktop is *defined by data here*, not by a host activation.

## Top-level options

| Option | Meaning |
|---|---|
| `enable` | Turn the whole feature on. |
| `parentInterface` | NIC used as the macvlan parent (required when any desktop uses macvlan). |
| `network.subnet` / `network.gateway` | Private macvlan network, default `192.168.88.0/24` / `192.168.88.1`. |
| `desktops.<name>` | Submodule per desktop (below). |

## Per-desktop options (the important ones)

- `outputs = [{ mode = "WxH@Hz"; ip = "..."; }]` — virtual monitors; one Sunshine each. All outputs of one desktop must share one `ip`; each output gets its own port base (47989, 48089, ...).
- `desktop.name = "gaming"` — reuse a named desktop def from the `desktops` module: its compositor package, `packages` and `extraConfig` are pulled in automatically.
- Per-container overrides that win over the def when set: `desktop.package` (e.g. `self.mkHyprlandPkg { ... }`), `desktop.extraConfig` (Lua appended to `base.lua`), `packages` (extra packages on `/bin` in the image), `extraVolumes`, `extraEnv`.
- `desktop.hostProfile = true` — expose the host's `/run/current-system/sw` read-only on PATH, so the container sees system-wide apps (bar, launcher, ...).
- `persistentHome = true` — keep `/home/user` across restarts (default: tmpfs).
- `uid`/`gid`/`extraGids` — the image generates its own passwd/group entry named `user`; put host device-group ids in `extraGids` (see below).
- `hostNetwork = true` — run in the host's network namespace instead of macvlan (fallback; see udev note). Then `ip` is only used for the CSRF origin and ports are allocated across all host-network desktops in name order — and all desktops share uinput devices.

## GPU access (most common failure)

`/dev/dri/card1` is `root:video` mode 0660, so the container user must belong to the host's `video` group id — list it in `extraGids` (e.g. `extraGids = [ 26 ];` from `getent group video`), or Hyprland fails with `CBackend::create() failed!`. Add the `uinput` group id too for keyboard/mouse streaming. `drmCard`, `renderNode`, and `devices` (NVIDIA nodes) default sensibly; tune only on unusual setups. The image shares the host `/nix/store` and `/run/opengl-driver`, so build packages from the same nixpkgs as the host.

## udev relay (macvlan input problem)

Containers on their own macvlan netns never receive udev hotplug events (the kernel and udevd only broadcast into the init netns). The module installs a `streaming-udev-relay` service: a small Python daemon listens to the host's libudev netlink broadcasts (group 2) and re-sends `input`/`hidraw` events into each container's netns via `setns`, so libinput sees Sunshine's uinput devices as they appear. If the relay misbehaves, fall back to `hostNetwork = true`.

## Sunshine inside the container

Defaults: `capture = "wlr"` (compositor screen capture), `encoder = "nvenc"`, `hevc_mode = 0`, web UI allowed on LAN, tray disabled. Per-output identity (name, port, state files, `output_name`, `audio_sink`, csrf origin) is set by the module and cannot be overridden; `sunshine.settings` adds extra keys only. `sunshine.package` defaults to `pkgs.sunshine.override { cudaSupport = true; }`.

## Status / unverified items

1. Launching `bin/hyprland` directly instead of `start-hyprland` (Hyprland may warn about it).
2. Input stack: `AQ_BACKENDS=headless,libinput` + `LIBSEAT_BACKEND=noop`.
3. Image/host nixpkgs must match (shared store + opengl driver).
4. Moonlight accepting `ip:port` for the 2nd+ output of a desktop.
