{
  lib,
  config,
  pkgs,
  ...
}:

let
  customNetworkName = "custom-network";
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

  # module config: always a plain set, optionally merged at top level
  config = {
    networking.useNetworkd = true;
    networking.enableIPv6 = true;
    services.resolved.enable = true;

    assertions = [
      {
        assertion = config.networking.custom.interface != "";
        message = "networking.custom.interface must be provided";
      }
    ]
    ++ lib.optionals (!config.networking.custom.dhcp) [
      {
        assertion = config.networking.custom.address != "";
        message = "Static IP requires address";
      }
      {
        assertion = config.networking.custom.gateway != "";
        message = "Static IP requires gateway";
      }
    ];
  };

  # **top-level conditional merge**: safe and works with built-in options
  # We return a list of attribute sets that will be merged into config
  # Here, we assign networking.systemd.networks based on DHCP/static
  config = lib.mkMerge [
    {
      # common assertions and flags
      networking.useNetworkd = true;
      networking.enableIPv6 = true;
      services.resolved.enable = true;
    }

    # static IP
    lib.mkIf
    (!config.networking.custom.dhcp)
    {
      networking.systemd.networks = {
        ${customNetworkName} = {
          matchConfig.Name = config.networking.custom.interface;
          networkConfig.DHCP = "no";
          address = config.networking.custom.address;
          gateway = config.networking.custom.gateway;
          DNS = [ config.networking.custom.gateway ];
        };
      };
    }

    # DHCP
    lib.mkIf
    config.networking.custom.dhcp
    {
      networking.systemd.networks = {
        ${customNetworkName} = {
          matchConfig.Name = config.networking.custom.interface;
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
