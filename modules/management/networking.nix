{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    networking.interface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Network interface name to configure.";
    };

    networking.dhcp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to use DHCP (true) or static IP (false).";
    };

    networking.address = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Static IP address with prefix (e.g., 192.168.88.254/24). Only used if dhcp=false.";
    };

    networking.gateway = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Gateway IP. Only used if dhcp=false. DNS will default to this.";
    };
  };

  # Merge assertions into config
  config = lib.mkMerge [

    # Basic interface assertion
    {
      networking.useNetworkd = true;
      networking.enableIPv6 = true;
      services.resolved.enable = true;

      assertions = [
        {
          assertion = config.networking.interface != "";
          message = "networking.interface must be provided";
        }
      ]
      ++ (lib.optionals (!config.networking.dhcp) [
        {
          assertion = config.networking.address != "";
          message = "Static IP is enabled but no 'networking.address' was provided.";
        }
        {
          assertion = config.networking.gateway != "";
          message = "Static IP is enabled but no 'networking.gateway' was provided.";
        }
      ]);
    }

    # Static IP configuration
    lib.mkIf
    (!config.networking.dhcp)
    {
      networking.systemd.network = {
        networks."custom-network" = {
          matchConfig.Name = config.networking.interface;
          networkConfig.DHCP = "no";
          address = config.networking.address;
          gateway = config.networking.gateway;
          DNS = [ config.networking.gateway ];
        };
      };
    }

    # DHCP configuration
    lib.mkIf
    config.networking.dhcp
    {
      networking.systemd.network = {
        networks."custom-network" = {
          matchConfig.Name = config.networking.interface;
          networkConfig.DHCP = "yes";
          dhcpConfig = {
            ClientIdentifier = "mac";
            UseDomains = "true";
            CriticalConnection = "true";
          };
        };
      };
    }
  ];
}
