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
    environment.systemPackages =
      with pkgs;
      [
        nixd
        nixfmt-tree
      ]
      ++ nixpkgsStable.vulkan-tools;

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
