{
  pkgs,
  ...
}:
let
  rebuild-script = pkgs.writeShellScriptBin "rebuild" (
    builtins.readFile "/etc/nixos/new configs/scripts/rebuild.sh"
  );
in
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    pkgs.nixfmt-tree
    pkgs.libnotify
    pkgs.nvd
    pkgs.vulnix
    pkgs.lm_sensors
    pkgs.fastfetch
    rebuild-script
  ];

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.settings.auto-optimise-store = true;
  services.cleaner.enable = true;
  services.autoupdater.enable = true;
}
