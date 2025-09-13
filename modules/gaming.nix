{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options = {
    enable.gaming = lib.mkEnableOption "enables gaming tools";
  };
  config = lib.mkIf config.enable.gaming {

  };
}
