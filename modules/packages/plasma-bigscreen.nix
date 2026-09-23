{
  self,
  inputs,
  lib,
  ...
}: {
  config = let
    mkPlasmaBigscreenPkg = {
      pkgs,
      extraPackages ? [],
    }: let
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

      startScript = pkgs.writeShellScriptBin "plasma-bigscreen" ''
        set -euo pipefail

        BIGSCREEN="${pkgs.kdePackages.plasma-bigscreen}"

        export QML2_IMPORT_PATH="$BIGSCREEN/lib/qt-6/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
        export QT_PLUGIN_PATH="$BIGSCREEN/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

        export QT_ENABLE_GLYPH_CACHE_WORKAROUND=1
        export PLASMA_INTEGRATION_USE_PORTAL=1
        export PLASMA_PLATFORM=mediacenter
        export QT_FILE_SELECTORS=mediacenter
        export PLASMA_DEFAULT_SHELL=org.kde.plasma.bigscreen

        export XDG_CONFIG_DIRS="$HOME/.config/plasma-bigscreen:/etc/xdg''${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}"

        case "''${1:---nested}" in
          --nested)
            echo "Starting nested Plasma Bigscreen..."
            echo "Press Ctrl+C to stop."

            QT_QPA_PLATFORM=offscreen \
              plasma-bigscreen-envmanager --apply-settings

            exec dbus-run-session \
              kwin_wayland \
                --xwayland \
                "plasmashell -p org.kde.plasma.bigscreen"
            ;;

          *)
            echo "Usage: plasma-bigscreen [--nested]"
            exit 1
            ;;
        esac
      '';

    in
      pkgs.symlinkJoin {
        name = "plasma-bigscreen-test";

        paths =
          plasmaPackages
          ++ extraPackages
          ++ [startScript];

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