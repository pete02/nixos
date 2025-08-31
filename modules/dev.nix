{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options = {
    dev.enable = lib.mkEnableOption "enables dev tools";
  };
  config = lib.mkIf config.dev.enable {
    environment.systemPackages = with pkgs; [
      vscode
      pkgs.nixd
      nixfmt-rfc-style
    ];

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
