{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    enable.books = lib.mkEnableOption "enables ebook tools";
  };
  config = lib.mkIf config.enable.books {
    environment.systemPackages = [ pkgs.calibre ];
  };
}
