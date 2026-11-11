# Streaming

Two flavors of Sunshine game streaming live in `modules/features/streaming/`:

| Flavor | Module file | Attr | Option | Use case |
|---|---|---|---|---|
| **Host-side Sunshine** | `host-streaming.nix` | `streaming-sunshine` | `streaming.sunshine` | This machine *is* the gaming desktop; Sunshine streams from it to a TV/box elsewhere. |
| **Containerised desktops** | `podman-streaming.nix` | `streaming-desktops` | `streaming.desktops` | This machine *hosts* whole Hyprland desktops in podman containers, each streamed out with its own Sunshine instance and virtual outputs. |

`default.nix` aggregates both into `nixosModules.streaming`, so activating `streaming` on a host pulls in both modules (each is inert until its `enable` is set).

## Host-side Sunshine — 3 lines

```nix
streaming.sunshine.enable = true;
streaming.sunshine.desktop = "gaming"; # default; names the desktop def that
                                       # supplies EDID, csrf origins, wrappers
```

The module itself no longer hardcodes monitor names, csrf origins, or wrapper scripts — those come from the named desktop def (`config.desktops.<name>`, see the `desktops` module). Details: [host-side Sunshine](streaming/host.md).

## Containerised desktops — minimum example

```nix
streaming.desktops = {
  enable = true;
  parentInterface = "enp4s0";          # macvlan parent NIC
  desktops.aria = {
    outputs = [{ mode = "3440x1440@60"; ip = "192.168.88.2"; }];
    desktop.name = "gaming";           # reuse a named desktop def
  };
};
```

Each desktop becomes a podman OCI image (headless Hyprland + one Sunshine per virtual output) on its own macvlan IP; Moonlight connects to `ip:port`. Details: [containerised desktops](streaming/podman.md).

## Where to read next

- How the host flavor gets its Hyprland-coupled pieces: [streaming/host.md](streaming/host.md)
- Containers, macvlan networking, udev relay, GPU/groups, ports: [streaming/podman.md](streaming/podman.md)
