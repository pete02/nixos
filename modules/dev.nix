{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options = {
    enable.dev = lib.mkEnableOption "enables dev tools";
  };
  config = lib.mkIf config.enable.dev {
    environment.systemPackages = with pkgs; [
      nixd
    ];
    enable.docker = true;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    nix.settings = {
      trusted-users = [
        "root"
        "pete"
      ];
    };
  };
}
