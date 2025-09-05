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
      docker
      docker-compose
      deno
    ];

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
