# Ginny — Raspberry Pi 5 TV Box (NixOS)

Host name: **ginny**. Fourth host alongside `raysha`, `aria`, `talia`.

## Goals

- NixOS on a Raspberry Pi 5, declarative and reproducible like the other hosts.
- KDE Plasma Bigscreen as the TV shell, driven primarily by the remote over HDMI-CEC.
- Streaming services (Yle Areena, YouTube) and Jellyfin/Kodi as first-class launchable apps.
- Room for arbitrary Linux apps and a browser fallback.
- Casting deferred entirely — not part of the first build.

## Verified constraints (checked 2026-09-23)

These change *how* the plan below is implemented, not the goals themselves:

1. **Plasma Bigscreen is a normal nixpkgs package now — no vendoring needed.** KDE folded Bigscreen into the mainline Plasma 6.7 release (stable since mid-June 2026) instead of keeping it as a separate unreleased snapshot, and nixpkgs unstable already carries it as `kdePackages.plasma-bigscreen`, generated the same way as the rest of `kdePackages`. It's a straight `environment.systemPackages` / `services.displayManager.sessionPackages` addition, not a hand-fetched derivation.
   - **Known rough edge:** first boot can fail with `HomeScreen unavailable` / `HomeHeader unavailable` / `org.kde.kdeconnect not installed`, because the package's QML import path doesn't pick up `kdeconnect-kde` correctly by default. The documented fix is a small overlay that adds `kdeconnect-kde` to `buildInputs` and extends the QML import path in `preFixup`. Bake this into `features/plasma-bigscreen.nix` from the start rather than discovering it at 2am on the sofa.
2. **Use the `nixos-raspberrypi` flake for board support, not plain `nixos-hardware`.** `nixos-hardware`'s Pi 5 entry is little more than a kernel-version assertion. `github:nvmd/nixos-raspberrypi` provides the firmware-partition bootloader, matched vendor kernel, and per-feature modules (`raspberry-pi-5.base`, `raspberry-pi-5.display-vc4`, `raspberry-pi-5.bluetooth`, etc.) and is the actively maintained path.
3. **Waydroid on Pi5/aarch64 is still rough.** Treat it as strictly optional and non-blocking, per the original plan — don't gate anything else on it working.
4. **Verify hardware video decode early.** Pi 5's GPU/decode block differs from Pi 4's; confirm accelerated playback for Areena/YouTube during the milestone phase rather than assuming it.
5. **Confirm your `flake.lock`'s nixpkgs input is new enough.** `kdePackages.plasma-bigscreen` only exists in nixpkgs revisions cut after Plasma 6.7 landed (~mid-June 2026 onward). If any host's `flake.lock` pins an older `nixpkgs` input, `plasma-bigscreen` simply won't exist there yet — check before assuming the package is available.

## Repo layout additions

```text
/etc/nixos/
├── flake.nix                              # + nixos-raspberrypi input
├── modules/
│   ├── features/
│   │   ├── plasma-bigscreen.nix           # NEW — shell/session/CEC, incl. kdeconnect-kde overlay fix
│   │   └── tv-apps.nix                    # NEW — Kodi/Jellyfin, browser, YouTube client, Waydroid
│   ├── hosts/
│   │   └── ginny/
│   │       ├── configration.nix           # NEW
│   │       ├── default.nix                # NEW
│   │       └── hardware-configuration.nix # NEW (see note below)
│   └── packages/
│       └── (tv-apps.nix, only if something like VacuumTube needs vendoring — see below)
```

Rationale for the split (matches your existing convention, e.g. `hyprland.nix` desktop feature vs. `gaming.nix` app-layer feature, and `packages/hyprland.nix` vs `features/hyprland.nix`):

- **`features/plasma-bigscreen.nix`** — owns the session: `pkgs.kdePackages.plasma-bigscreen` straight from nixpkgs, `xdg.portal.configPackages`, `services.displayManager.sessionPackages`, `defaultSession = "plasma-bigscreen-wayland"`, autologin, HDMI-CEC (`hardware.libcec`/`cec-utils`, whatever udev rules it needs), and the small overlay fixing the `kdeconnect-kde` QML import path. Nothing about individual apps lives here. This is the analogue of `hyprland.nix`.
- **`features/tv-apps.nix`** — owns what's launchable from the shell: Kodi (+ Jellyfin plugin config), a browser package for fullscreen webapp fallback, the YouTube client (VacuumTube or fallback webapp), and Waydroid as an optional, `lib.mkDefault false`-style toggle. This is the analogue of `gaming.nix`.
- **`packages/`** — no longer needed for Bigscreen itself now that it's upstream. Only reach for a `modules/packages/tv-apps.nix` if something in the app layer (VacuumTube, most likely) isn't packaged in nixpkgs and needs vendoring — don't create it preemptively.

## modules/hosts/ginny/

- **`default.nix`** — imports `../../features/plasma-bigscreen.nix`, `../../features/tv-apps.nix`, whatever shared `features/common.nix`/`connectivity.nix` you already pull into other hosts, plus the `nixos-raspberrypi` board modules (`raspberry-pi-5.base`, `.display-vc4`, `.bluetooth`).
- **`configration.nix`** — host-specific overrides (hostname, locale, users, CEC device quirks, whatever `raysha`/`aria`/`talia` put here), kept consistent with the existing typo'd filename for grep-ability across hosts.
- **`hardware-configuration.nix`** — on Pi boards booted via the firmware partition, this won't look like a normal `nixos-generate-config` output. Expect it to mostly hold filesystem/swap definitions generated after first boot; the actual board/GPU/bootloader wiring lives in the `nixos-raspberrypi` modules imported from `default.nix`, not in this file.

## flake.nix

Add the input:

```nix
inputs.nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
```

Thread it into `modules/parts.nix` the same way your other flake inputs reach host configs, and import the board modules from `modules/hosts/ginny/default.nix` as noted above.

## Application strategy (unchanged priorities, now file-scoped)

| App | Priority | Lives in | Notes |
|---|---|---|---|
| Yle Areena | High | `tv-apps.nix` | Try Waydroid Android TV build → fullscreen webapp → dedicated client, in that order. Webapp stays as fallback even if Waydroid works. |
| YouTube | Medium | `tv-apps.nix` | VacuumTube if it packages cleanly; fullscreen webapp otherwise. |
| Jellyfin | Secondary | `tv-apps.nix` | Via Kodi's Jellyfin plugin, not a separate media UI. |
| Browser | Fallback | `tv-apps.nix` | For anything without a dedicated app. |
| Waydroid | Optional | `tv-apps.nix`, `lib.mkDefault false` | Never a hard dependency for the base system. |

## Milestone checklist

1. `flake.nix` input + `modules/hosts/ginny/{default,configration}.nix` boot to a display at the right resolution.
2. `features/plasma-bigscreen.nix` gets `kdePackages.plasma-bigscreen` on screen as the session (apply the kdeconnect-kde overlay fix up front).
3. HDMI-CEC confirmed working from the actual remote.
4. Sleep/wake/power behavior sane.
5. `features/tv-apps.nix`: browser in, confirmed launchable from Bigscreen.
6. VacuumTube or YouTube webapp in and navigable with the remote.
7. Kodi + Jellyfin in and confirmed.
8. Waydroid + Areena Android TV build investigated, without blocking anything above.
9. Casting: explicitly out of scope until everything above is solid.

## Deferred

Casting (Miracast, Chromecast-style, AirPlay, PC/phone → TV) — investigate later as another `tv-apps.nix`-style feature, not something that reshapes this structure.