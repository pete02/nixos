{self,inputs,...}:{
  flake.nixosModules.connectivity-wired={config, lib, ...}:{
    options = {
      connectivity = {
        managed = {
          enable = lib.mkEnableOption "managed wired networking via networkd";

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
            description = "Static IP address (only if dhcp = false)";
          };

          gateway = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Gateway (only if dhcp = false)";
          };
        };
      };
    };

    config =lib.mkIf config.connectivity.managed.enable {
      assertions =
        [
          {
            assertion = config.connectivity.managed.interface != "";
            message = "connectivity.managed.interface must be set";
          }
        ]
        ++ lib.optionals (!config.connectivity.managed.dhcp) [
          {
            assertion = config.connectivity.managed.address != "";
            message = "Static IP requires connectivity.managed.address";
          }
          {
            assertion = config.connectivity.managed.gateway != "";
            message = "Static IP requires connectivity.managed.gateway";
          }
        ];

      networking = {
        useNetworkd = true;
        enableIPv6 = true;
      };
      services.resolved.enable = true;

      systemd.network.networks =
        lib.optionalAttrs config.connectivity.managed.dhcp {
          "10-dhcp-wired" = {
            matchConfig.Name = config.connectivity.managed.interface;
            networkConfig.DHCP = "yes";
            dhcpV4Config = {
              ClientIdentifier = "mac";
              UseDomains = true;
              CriticalConnection = true;
            };
          };
        }
        // lib.optionalAttrs (!config.connectivity.managed.dhcp) {
          "10-static-wired" = {
            matchConfig.Name = config.connectivity.managed.interface;
            networkConfig.DHCP = "no";
            address = [config.connectivity.managed.address];
            gateway = [config.connectivity.managed.gateway];
            dns = [config.connectivity.managed.gateway];
          };
        };
    };
  };
}