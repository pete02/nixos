{ ... }: {
  flake.nixosModules.gaming-graphics = { lib, pkgs, config, ... }: {
    options.gaming.graphics =
      lib.mkEnableOption "Gaming graphics utilities";

    config = lib.mkIf config.gaming.graphics {
      environment.systemPackages = with pkgs; [
        mesa-demos
        dejavu_fonts
      ];
    };
  };
}