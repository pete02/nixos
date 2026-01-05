{
  lib,
  config,
  pkgs,
  ...
}:

let
  enableStatic = !config.networking.custom.dhcp;
in
{
  # Step 1: define options for the module
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

  # Step 2: define module config
  config = {
    # Always enable systemd-networkd and resolved
    networking.useNetworkd = true;
    networking.enableIPv6 = true;
    services.resolved.enable = true;

    # Assertions
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

    # Step 3: set networking.systemd.networks using built-in option
    networking.systemd.networks = lib.mkMerge [
      # Static IP
      lib.mkIf
      enableStatic
      {
        "custom-network" = {
          matchConfig.Name = config.networking.custom.interface;
          networkConfig.DHCP = "no";
          address = config.networking.custom.address;
          gateway = config.networking.custom.gateway;
          DNS = [ config.networking.custom.gateway ];
        };
      }

      # DHCP
      lib.mkIf
      (config.networking.custom.dhcp)
      {
        "custom-network" = {
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
  };
}
