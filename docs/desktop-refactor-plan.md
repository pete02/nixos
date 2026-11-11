# Desktop refactor plan — `shells` / `streaming` / `desktops`

**TL;DR** Split the current `desktop` feature into three: **shells** (just the window-manager shells), **streaming** (host-side Sunshine + containerised streaming desktops), and **desktops** (named, complete desktop definitions — shell + packages + config — that hosts and streaming containers activate by name).

## New layout

```
features/shells/    (was features/desktop/, minus streaming & services packages)
  default.nix → nixosModules.shells imports shells-hyprland, shells-wayle,
                shells-bigscreen, shells-displaymanager, shells-selection,
                shells-pegasus-cage, shells-hdmi-cec
features/streaming/ (NEW)
  default.nix → nixosModules.streaming imports streaming-sunshine + streaming-desktops
  sunshine/  ← gaming/sunshine (option streaming.sunshine, shell-aware)
  desktops/  ← desktop/streaming (option streaming.desktops, consumes desktops defs)
features/desktops/  (NEW)
  default.nix → nixosModules.desktops: named desktops (gaming, work, kiosk) as
                options desktops.<name>.{shell, packages, hyprland extraConfig,
                wayle extraConfig, services cleaner} + selector desktops.desktop
```

`lib/hosts.nix` `featureModules`: replace `desktop` with `shells`, add `streaming`, `desktops`; gaming keeps only steam/rpcs3/performance/graphics/compatibility.

## Steps

### Phase A — `desktop` → `shells` — ✅ DONE

- [x] 1. Move `modules/features/desktop/` → `modules/features/shells/`; attrs `desktop-*` → `shells-*`; `flake.nixosModules.desktop` → `.shells`
- [x] 2. Rename options: `desktop.hyprland.*` → `shells.hyprland.*`, same for `wayle`, `plasma-bigscreen`, `pegasus-cage`, `hdmi-cec`. `displayManager.*` stays top-level (already a global namespace)
- [~] 3. Split `desktop-services.nix`: WM-invariant plumbing (pipewire, xdg.portal, rtkit, upower, pam.swaylock) stays in shells under `shells.services.system`; the hardcoded systemPackages/fonts/firefox/cleaner-service move to **desktops** — *deferred to Phase C; Phase A only renamed `desktop.enable` → `shells.enable`, `desktop.services.cleaner` → `shells.services.cleaner` and kept packages in place so nothing breaks*
- [x] 4. Fix the mutual-exclusion assertion in `selection.nix` (it also has a stale `plasmaBigscreen` message)
- [x] 5. Keep `flake.mkHyprlandPkg` in shells-hyprland — streaming depends on it

Also done in Phase A: `lib/hosts.nix` `featureModules` `desktop` → `shells`; all host refs updated (`aria/raysha/talia` `_hyprland.nix` → `shells.hyprland`, `raysha/talia` `_configuration.nix` → `shells = {...}`, `alanna` → `shells.pegasus-cage.enable`); `shells-streaming` still imported by the `shells` aggregator so aria's `gaming.streaming` keeps working; `nix flake check` passes.

### Phase B — new `streaming` module (holds *both* Sunshine flavors)

6. `features/streaming/sunshine/` ← `features/gaming/sunshine/`: option `streaming.sunshine` + `streaming.sunshine.desktop` (str, default `"gaming"`) so the Hyprland-coupled scripts, csrf origin, and EDID/monitor handling come from the activated desktop def instead of hardcoding `hyprctl`/hyprpanel names and `https://192.168.88.241:47990`
7. `features/streaming/desktops/` ← `features/desktop/streaming/`: rename option `gaming.streaming` → `streaming.desktops`; each container gets `desktop.name = "gaming"` pulling shell package, packages, and extraConfig from `config.desktops.<name>` (the `desktop.{package,extraConfig}` attrs become optional overrides)
8. Update `gaming/default.nix` to drop the `gaming-sunshine` import

### Phase C — new `desktops` module

9. `features/desktops/default.nix` defines named desktops as data with per-desktop options (`desktops.<name>.{shell, packages, hyprland.extraConfig, wayle.extraConfig, services.cleaner}`):
   - **gaming** = current Hyprland + full services package list + moonlight-qt + cleaner
   - **work** = Hyprland + slimmer package set (to be picked during impl)
   - **kiosk** = pegasus-cage shell
   - convenience selector `desktops.desktop = "gaming"` enables the matching desktop
10. Hosts (depends on A–C):
   - **raysha**: `desktops.desktop = "gaming"`, `streaming.sunshine.enable = true`; `_hyprland.nix` → `_desktops.nix` with only the Dell/AOC/Philips monitor overlay
   - **talia**: `desktops.desktop = "work"` (or gaming); `_desktops.nix` keeps Lenovo/Dell monitors + wayle bar overlay
   - **aria**: `_desktops.nix` keeps the Philips TV monitor overlay; `streaming.desktops.desktops.aria.desktop.name = "gaming"`
   - **alanna**: `desktops.desktop = "kiosk"` replaces `desktop.pegasus-cage.enable`
   - **eris**: unchanged
11. `lib/hosts.nix` `featureModules`: replace `desktop` with `shells`, add `streaming` + `desktops`

### Verification

12. `nix flake check`; evaluate each `nixosConfigurations.<host>`; grep for leftover `desktop.(hyprland|wayle|enable|services)` and `gaming.(sunshine|streaming)` references

## Decisions (confirmed)

- Full `shells.*` option rename
- Desktops defined as module options per desktop, with defaults inside the desktops module
- Streaming module includes both Sunshine variants (host-side and container-side)
- Hosts keep small monitor-only overlays on top of named desktop defs

## Critical files

- `modules/lib/hosts.nix` (featureModules)
- `modules/features/desktop/**` → `shells/**`
- `modules/features/gaming/sunshine/**` + `modules/features/desktop/streaming/**` → `streaming/**`
- `modules/features/desktops/default.nix` (new)
- `modules/hosts/{aria,raysha,talia,alanna}/_configuration.nix` + `_hyprland.nix` (rename `_desktops.nix`)

## Open items

- `displayManager` stays a top-level option namespace (recommended, already global)
- `shells.services.system` default: auto-true when any shell enabled
- Desktop names: fixed set `gaming`/`work`/`kiosk` — decide the work-desktop package set during impl
- `streaming.sunshine.desktop` default: `"gaming"` vs required-to-set
- The container-side udev relay / macvlan network machinery in `streaming/desktops` stays untouched — only the desktop-def consumption changes
