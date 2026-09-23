{
  self,
  inputs,
  lib,
  ...
}: {
  options = {
    plasmaBigscreenExtraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
    };
  };

  config = let
    mkPlasmaBigscreenPkg = {
      pkgs,
      extraPackages ? [],
    }: let

      # Everything needed for a reasonably complete nested
      # Plasma Bigscreen session.
      plasmaPackages = with pkgs.kdePackages; [
        plasma-workspace
        plasma-bigscreen
        kactivitymanagerd
        kglobalaccel
        powerdevil
        kwin
        plasma-nm
        plasma-pa
        milou
        kscreen
        kio
        kdeconnect-kde
      ];

      runtimePackages =
        plasmaPackages
        ++ extraPackages;

      runtimeEnv = pkgs.writeShellScript "plasma-bigscreen-env" ''
        set -euo pipefail

        BIGSCREEN=${
          pkgs.kdePackages.plasma-bigscreen
        }

        export QML2_IMPORT_PATH="$BIGSCREEN/lib/qt-6/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

        export QT_PLUGIN_PATH="$BIGSCREEN/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

        export QT_ENABLE_GLYPH_CACHE_WORKAROUND=1
        export PLASMA_INTEGRATION_USE_PORTAL=1
        export PLASMA_PLATFORM=mediacenter
        export QT_FILE_SELECTORS=mediacenter
        export PLASMA_DEFAULT_SHELL=org.kde.plasma.bigscreen

        export XDG_CONFIG_DIRS="$HOME/.config/plasma-bigscreen:/etc/xdg''${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}"

        exec "$@"
      '';

      startScript = pkgs.writeShellScriptBin "plasma-bigscreen-test" ''
        set -euo pipefail

        export QT_ENABLE_GLYPH_CACHE_WORKAROUND=1
        export PLASMA_INTEGRATION_USE_PORTAL=1
        export PLASMA_PLATFORM=mediacenter
        export QT_FILE_SELECTORS=mediacenter
        export PLASMA_DEFAULT_SHELL=org.kde.plasma.bigscreen

        export XDG_CONFIG_DIRS="$HOME/.config/plasma-bigscreen:/etc/xdg''${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}"

        # Let Bigscreen generate its configuration before the shell starts.
        QT_QPA_PLATFORM=offscreen \
          plasma-bigscreen-envmanager --apply-settings

        exec dbus-run-session \
          kwin_wayland \
            "plasmashell -p org.kde.plasma.bigscreen"
      '';

    in pkgs.symlinkJoin {
      name = "plasma-bigscreen-test";

      paths =
        runtimePackages
        ++ [
          startScript
          runtimeEnv
        ];

      meta = {
        description = "Nested Plasma Bigscreen test environment";
      };
    };

  in {
    flake.packages.x86_64-linux.plasmaBigscreen =
      mkPlasmaBigscreenPkg {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      };

    flake.mkPlasmaBigscreenPkg = mkPlasmaBigscreenPkg;
  };
}