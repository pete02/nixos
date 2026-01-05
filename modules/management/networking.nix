{ lib, config, ... }:
{
  options = {
    net = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Network interface to configure";
      };

      dhcp = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use DHCP (true) or static IP (false)";
      };

      address = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Static IP (only if dhcp=false)";
      };

      gateway = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Gateway (only if dhcp=false)";
      };
    };
  };
  config = {
    assertions = [
      {
        assertion = config.net.interface != "";
        message = "networking.custom.interface must be provided";
      }
    ];
  };
  config = {
    systemd.network.networks."10-wired" = {
      matchConfig.Name = "enp12s0"; # replace with your NIC name
      networkConfig.DHCP = "yes";
      dhcpConfig = {
        ClientIdentifier = "mac";
        UseDomains = "true";
        CriticalConnection = "true";
      };
    };
  };
}
