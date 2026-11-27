{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.plasma-bigscreen;
in {
  options.programs.plasma-bigscreen = {
    enable = lib.mkEnableOption "the Plasma Bigscreen session";

    package = lib.mkOption {
      type = lib.types.package;
      # Built from the host's pkgs, so it matches the host's Plasma and overlays
      default = pkgs.kdePackages.callPackage ./package.nix {};
      defaultText = lib.literalExpression "pkgs.kdePackages.callPackage ./package.nix {}";
      description = "The Plasma Bigscreen package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versions.majorMinor pkgs.kdePackages.plasma-workspace.version == "6.6";
        message = "This Plasma Bigscreen flake targets Plasma 6.6; this host has ${pkgs.kdePackages.plasma-workspace.version}.";
      }
    ];

    services.desktopManager.plasma6.enable = true;

    # Registers the session only; the display manager and login stay your choice
    services.displayManager.sessionPackages = [cfg.package];

    # Needed in the system profile so the session's QML imports resolve
    environment.systemPackages =
      [cfg.package]
      ++ (with pkgs.kdePackages; [
        kdeconnect-kde
        kirigami-addons
        milou
        plasma-nano
        plasma-nm
        plasma-pa
      ]);

    # Controller input; the session user must also be in the "input" group
    boot.kernelModules = ["uinput"];
    services.udev.packages = [cfg.package];
  };
}
