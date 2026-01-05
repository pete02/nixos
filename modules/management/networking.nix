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
      description = "Use DHCP (true) or static IP (false)";
    };

    networking.address = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Static IP (only if dhcp=false)";
    };

    networking.gateway = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Gateway (only if dhcp=false)";
    };
  };

  config = {
    # Always enable networkd & resolved
    networking.useNetworkd = true;
    networking.enableIPv6 = true;
    services.resolved.enable = true;

    # Assertions
    assertions = [
      {
        assertion = config.networking.interface != "";
        message = "networking.interface must be provided";
      }
    ]
    ++ lib.optionals (config.networking.dhcp == false) [
      {
        assertion = config.networking.address != "";
        message = "Static IP is enabled but no address provided";
      }
      {
        assertion = config.networking.gateway != "";
        message = "Static IP is enabled but no gateway provided";
      }
    ];

    # Use mkIf inside config so config is evaluated lazily
    networking.systemd.network =
      lib.mkIf (!config.networking.dhcp) {
        networks."custom-network" = {
          matchConfig.Name = config.networking.interface;
          networkConfig.DHCP = "no";
          address = config.networking.address;
          gateway = config.networking.gateway;
          DNS = [ config.networking.gateway ];
        };
      }
      // lib.mkIf (config.networking.dhcp) {
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
  };
}
