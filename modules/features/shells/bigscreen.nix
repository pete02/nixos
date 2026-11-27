{
  self,
  inputs,
  lib,
  ...
}: let
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
        
      passthru.providedSessions = ["plasma-bigscreen-wayland"];

      meta = {
        description = "KDE Plasma Bigscreen session";
        mainProgram = "plasma-bigscreen";
      };
    };
in {
  flake.mkPlasmaBigscreenPkg = mkPlasmaBigscreenPkg;

  flake.packages.x86_64-linux.plasmaBigscreen = mkPlasmaBigscreenPkg {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  };

  flake.nixosModules.shells-bigscreen = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.shells.plasma-bigscreen;

    plasmaBigscreenPkg = self.mkPlasmaBigscreenPkg {
      inherit pkgs;
    };
  in {
    options.shells.plasma-bigscreen = {
      enable = lib.mkEnableOption "Plasma Bigscreen desktop";
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        plasmaBigscreenPkg
      ];

      services.desktopManager.plasma6.enable = true;

      displayManager = {
        enable = true;
        backend = "sddm";
        autoLogin = true;
        sessionPackage = plasmaBigscreenPkg;
        sessionName = "plasma-bigscreen-wayland";
      };
    };
  };
}
