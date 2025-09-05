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
    virtualisation.docker.enable = true;
    virtualisation.docker.storageDriver = "btrfs";
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
    
    environment.systemPackages = with pkgs; [
      vscode
      pkgs.nixd
      nixfmt-rfc-style
      deno
    ];

    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
