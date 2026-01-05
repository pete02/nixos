{
  lib,
  config,
  pkgs,
  ...
}:

let
  customNetworkName = "custom-network";
  enableStatic = !config.networking.custom.dhcp;
in
{
  options = {
    networking.custom = {
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

  # single config block
  config = lib.mkMerge [

    {
      networking.useNetworkd = true;
      networking.enableIPv6 = true;
      services.resolved.enable = true;

      # assertions
      assertions = [
        {
          assertion = config.networking.custom.interface != "";
          message = "networking.custom.interface must be provided";
        }
      ]
      ++ lib.optionals enableStatic [
        {
          assertion = config.networking.custom.address != "";
          message = "Static IP requires address";
        }
        {
          assertion = config.networking.custom.gateway != "";
          message = "Static IP requires gateway";
        }
      ];
    }

    # conditional networking.systemd.networks
    {
      networking.systemd.networks = lib.mkMerge [

        # static
        lib.mkIf
        enableStatic
        {
          ${customNetworkName} = {
            matchConfig.Name = config.networking.custom.interface;
            networkConfig.DHCP = "no";
            address = config.networking.custom.address;
            gateway = config.networking.custom.gateway;
            DNS = [ config.networking.custom.gateway ];
          };
        }

        # DHCP
        lib.mkIf
        config.networking.custom.dhcp
        {
          ${customNetworkName} = {
            matchConfig.Name = config.networking.custom.interface;
            networkConfig.DHCP = "yes";
            dhcpConfig = {
              ClientIdentifier = "mac";
              UseDomains = "true";
              CriticalConnection = "true";
            };
          };
        }

      ];
    }

  ];
}
