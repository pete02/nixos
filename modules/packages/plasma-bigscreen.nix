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
      kdePackages = pkgs.kdePackages;

      plasmaBigscreen = kdePackages.plasma-bigscreen;
      plasmaWorkspace = kdePackages.plasma-workspace;

      plasmaPackages = with kdePackages; [
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

      plasmaBigscreenLauncher = pkgs.writeShellScriptBin "plasma-bigscreen" ''
        set -euo pipefail

        export PATH="${plasmaBigscreen}/bin:${plasmaWorkspace}/bin:${plasmaWorkspace}/libexec:$PATH"

        exec "${plasmaWorkspace}/libexec/plasma-dbus-run-session-if-needed" \
          "${plasmaBigscreen}/bin/plasma-bigscreen-wayland"
      '';
    in
      pkgs.symlinkJoin {
        name = "plasma-bigscreen";
        paths =
          plasmaPackages
          ++ extraPackages
          ++ [
            plasmaBigscreenLauncher
          ];

        meta = {
          description = "KDE Plasma Bigscreen session";
          mainProgram = "plasma-bigscreen";
        };
      };
  in {
    flake.packages.x86_64-linux.plasmaBigscreen = mkPlasmaBigscreenPkg {
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    };

    flake.mkPlasmaBigscreenPkg = mkPlasmaBigscreenPkg;
  };
}
