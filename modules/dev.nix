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
      vscode-fhs
      nixd
      nixfmt-tree
    ];
    docker.enable = true;

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
