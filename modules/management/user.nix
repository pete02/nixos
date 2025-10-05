{
  lib,
  config,
  inputs,
  ...
}:
let
  cof = config;
in
{
  options.username = lib.mkOption {
    type = lib.types.str;
    description = "The username of the main user";
  };
  options.enable.user = lib.mkEnableOption "enables user";
  config = lib.mkIf config.enable.user{
    users.users.${cof.username} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "seat"
      ];
    };
      };
}
