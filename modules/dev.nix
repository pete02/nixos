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

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
