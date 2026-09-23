# Raspberry Pi TV Box — NixOS Architecture Plan

## Goals

Build a Raspberry Pi 5 smart-TV box that:

- Uses **NixOS** as the base operating system.
- Uses **KDE Plasma Bigscreen** as the primary TV/10-foot interface.
- Is primarily navigable with the **TV remote over HDMI-CEC**.
- Treats web/streaming services as first-class applications.
- Supports **Yle Areena** as a high-priority service.
- Supports **YouTube** through a TV-friendly Linux client such as VacuumTube where practical.
- Supports **Jellyfin**, despite local media being a secondary use case.
- Leaves room for arbitrary Linux applications and future experimentation.
- Keeps casting as a later subsystem rather than making it part of the initial architecture.
- Remains declarative and reproducible through NixOS.

## High-level architecture

```text
Raspberry Pi 5
└── NixOS
    ├── Boot / system services
    ├── Graphics stack
    │   └── Wayland
    ├── KDE Plasma Bigscreen
    │   ├── TV launcher / home screen
    │   ├── D-pad / remote-oriented navigation
    │   └── HDMI-CEC input
    │
    ├── Native TV applications
    │   ├── VacuumTube / YouTube
    │   ├── Browser / webapps
    │   └── Other future applications
    │
    ├── Media
    │   └── Kodi / Jellyfin
    │
    └── Optional Android compatibility
        └── Waydroid
            └── Yle Areena Android TV app (experimental)
```

## Why Plasma Bigscreen

Plasma Bigscreen should own the TV UX rather than Kodi.

This provides a common remote-first shell around heterogeneous applications:

- Native Linux applications can be launched fullscreen.
- Kodi does not have to be the system shell.
- Webapps can coexist with native applications.
- Android applications can potentially coexist through Waydroid.
- KDE's TV-oriented input model can provide consistent D-pad navigation.
- HDMI-CEC can expose the physical TV remote to the system.

The objective is for the user to think in terms of **TV applications**, not Linux windows.

## Input model

Primary:

```text
TV remote
    ↓
HDMI-CEC
    ↓
Plasma Bigscreen
    ↓
D-pad / Select / Back / Home / playback controls
```

Secondary fallback:

- Keyboard and mouse for setup/debugging.
- KDE Connect or similar remote-control mechanisms if useful.
- Application-specific input where required.

The normal operating assumption should be that a keyboard and mouse are **not required**.

## Application strategy

### Yle Areena

Priority: **high**.

Test three possible implementations, in this order:

1. **Android TV application through Waydroid**
   - Prefer the actual Android TV build rather than a phone-oriented Android application.
   - Verify D-pad navigation.
   - Verify video playback and hardware acceleration.
   - Verify audio output.
   - Verify login and other required functionality.
   - Verify whether DRM/protected playback works.

2. **Fullscreen webapp**
   - Chromium/Firefox in a dedicated fullscreen mode.
   - Test D-pad/keyboard navigation.
   - Map CEC input to keyboard navigation where appropriate.
   - Keep this as a fallback even if the Android application works.

3. **Dedicated Linux frontend/client**
   - Only investigate if the first two approaches are inadequate.

The goal is not merely to make Areena technically run; it must be **pleasant to use from the sofa with the TV remote**.

### YouTube

Preferred initial approach:

- Use a TV-friendly Linux client such as VacuumTube if it integrates cleanly with Bigscreen.
- Otherwise use a fullscreen webapp.
- Evaluate navigation entirely with the TV remote.

### Jellyfin

Use Kodi/Jellyfin integration rather than implementing another media UI.

```text
Plasma Bigscreen
    ↓
Kodi
    ↓
Jellyfin
```

Jellyfin is secondary to streaming services but should remain a polished, remote-friendly option.

### Generic browser

Keep a browser available for:

- websites without dedicated applications,
- temporary solutions,
- services not otherwise supported,
- general browsing.

The browser should not be assumed to provide a perfect TV UX. Prefer dedicated TV-oriented applications where they exist.

## Android compatibility

Investigate **Waydroid** as an optional compatibility layer.

Potential architecture:

```text
NixOS
└── Plasma Bigscreen
    └── Waydroid
        └── Android TV applications
```

First candidate: Yle Areena Android TV.

Important unknowns to test on the Pi 5:

- GPU acceleration
- video decoding
- audio
- D-pad input
- Android TV launcher/application behavior
- networking
- DRM/protected video
- Google Play/service dependencies
- performance and memory usage

Do not make Waydroid a hard dependency for the base system. The Linux/web implementation of a service should remain available as a fallback.

## Graphics/session architecture

Initial target:

```text
systemd
  ↓
graphical login/session
  ↓
Wayland
  ↓
Plasma Bigscreen
```

Avoid building a custom compositor or TV shell initially. Let KDE handle:

- display management,
- application launching,
- focus,
- input,
- session management,
- the Bigscreen UI.

Only replace individual pieces if a concrete requirement cannot be met.

## NixOS module structure

Suggested structure:

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix
├── modules/
│   ├── hosts/
│   │   └── <tv-box-name>/
│   │       ├── default.nix
│   │       └── hardware.nix
│   │
│   ├── desktop/
│   │   └── plasma-bigscreen.nix
│   │
│   ├── applications/
│   │   ├── kodi.nix
│   │   ├── youtube.nix
│   │   ├── browser.nix
│   │   └── waydroid.nix
│   │
│   └── services/
│       └── ...
│
└── scripts/
    └── ...
```

The exact structure can follow the existing NixOS configuration conventions rather than being imposed rigidly.

## Initial milestone

The first working prototype should be deliberately small:

1. Install NixOS on the Raspberry Pi 5.
2. Get the display output working reliably at the TV's desired resolution/refresh rate.
3. Install and configure Plasma Bigscreen.
4. Verify HDMI-CEC remote input.
5. Verify sleep/wake/power behavior.
6. Install a browser.
7. Install/test VacuumTube or another YouTube client.
8. Install Kodi and verify Jellyfin.
9. Investigate Waydroid and the Yle Android TV application.
10. Only after these work, investigate casting.

## Definition of success

The system should eventually behave like this:

```text
Turn on TV
    ↓
Plasma Bigscreen home screen
    ↓
Pick Yle / YouTube / Jellyfin / Browser
    ↓
Navigate primarily with TV remote
    ↓
Watch content
    ↓
Back/Home returns to the TV interface
```

A keyboard and mouse should be useful for administration and exceptional cases, but **not part of normal TV operation**.

## Explicitly deferred

### Casting

Do not make casting part of the first implementation.

Later investigate separately:

- Miracast screen mirroring
- Chromecast-style media casting
- AirPlay
- PC → TV streaming
- phone → TV streaming

Casting should integrate into Plasma Bigscreen as another TV application/service rather than determine the architecture of the rest of the system.

## Design principle

Prefer existing, mature components over implementing TV functionality ourselves:

- **NixOS** → system and reproducibility
- **Plasma Bigscreen** → TV shell and input UX
- **Waydroid** → Android compatibility
- **Kodi** → media playback/Jellyfin
- **VacuumTube or equivalent** → YouTube
- **Browser** → arbitrary web services
- **CEC** → physical remote

Only build custom components where the existing ecosystem fails to provide the desired remote-first experience.
