{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    qtile.enable = lib.mkEnableOption "enables qtile";
  };
  config = lib.mkIf config.qtile.enable {
    services.xserver = {
      enable = true;
      windowManager.qtile.enable = true;
      xkb.layout = "fi";
    };
    environment.systemPackages= with pkgs; [
      kitty
    ];
  };

}
