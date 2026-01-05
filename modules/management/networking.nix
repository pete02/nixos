{
  lib,
  config,
  pkgs,
  ...
}:

{
  options = {
    net.interface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Network interface name to configure.";
    };

    net.dhcp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use DHCP (true) or static IP (false)";
    };

    net.address = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Static IP (only if dhcp=false)";
    };

    net.gateway = lib.mkOption {
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
        assertion = config.net.interface != "";
        message = "networking.interface must be provided";
      }
    ]
    ++ lib.optionals (config.net.dhcp == false) [
      {
        assertion = config.net.address != "";
        message = "Static IP is enabled but no address provided";
      }
      {
        assertion = config.net.gateway != "";
        message = "Static IP is enabled but no gateway provided";
      }
    ];

    # Use mkIf inside config so config is evaluated lazily
    networking.systemd.networks =
      lib.mkIf (!config.net.dhcp) {
        "custom-network" = {
          matchConfig.Name = config.net.interface;
          networkConfig.DHCP = "no";
          address = config.net.address;
          gateway = config.net.gateway;
          DNS = [ config.net.gateway ];
        };
      }
      // lib.mkIf (config.net.dhcp) {
        "custom-network" = {
          matchConfig.Name = config.net.interface;
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
