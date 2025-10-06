{ lib, config, ... }:
with lib;
{
  options = {
    services.enable.ssh = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable ssh";
    };
  };
  config = mkIf config.services.enable.ssh {
    services.openssh = {
      enable = true;
      ports = [ 22 ];
      settings = {
        PasswordAuthentication = true;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [ "pete" ];
      };
    };
  };
}
