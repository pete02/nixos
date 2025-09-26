{ pkgs, lib, ... }:
{
  options = {
    enable.logitech = lib.mkEnableOption "Enable Solaar (logitech hub alternative)";
  };
  config = {
    environment.systemPackages = [ pkgs.piper ];
  };
}
