{ lib, config, ... }:
{
  options = {
    net = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
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

  config = lib.mkIf config.net.enable {
    assertions = [
      {
        assertion = config.net.interface != "";
        message = "networking.custom.interface must be provided";
      }
    ]
    ++ lib.optionals (!config.net.dhcp) [
      {
        assertion = config.net.address != "";
        message = "Static IP requires address";
      }
      {
        assertion = config.net.gateway != "";
        message = "Static IP requires gateway";
      }
    ];
    networking.useNetworkd = true;
    networking.enableIPv6 = true;
    services.resolved.enable = true;

    systemd.network.networks."10-dhcp-wired" = lib.mkIf config.net.dhcp {
      matchConfig.Name = "${config.net.interface}"; # replace with your NIC name
      networkConfig.DHCP = "yes";
      dhcpConfig = {
        ClientIdentifier = "mac";
        UseDomains = "true";
        CriticalConnection = "true";
      };
    };

    systemd.network.networks."10-static-wired" = lib.mkIf (!config.net.dhcp) {
      matchConfig.Name = "${config.net.interface}";
      networkConfig.DHCP = "no";
      address = [ config.net.address ];
      gateway = [ config.net.gateway ];
    };
  };
}
