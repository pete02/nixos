{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Select internationalisation properties.
  time.timeZone = "Europe/Helsinki";
  i18n.defaultLocale = "fi_FI.UTF-8";
}
