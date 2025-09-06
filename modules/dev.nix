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
      nixfmt-tree
    ];
    podman.enable = true;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
