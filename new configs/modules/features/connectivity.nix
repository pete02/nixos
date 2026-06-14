{ self, inputs, ... }: {
  flake.nixosModules.connectivity = { lib, config, pkgs, ... }: {
    options = {
      connectivity = {
        bluetooth = lib.mkEnableOption "bluetooth";
        wireless  = lib.mkEnableOption "wireless via NetworkManager";

        managed = {
          enable = lib.mkEnableOption "managed wired networking via networkd";

          interface = lib.mkOption {
            type        = lib.types.str;
            default     = "";
            description = "Network interface to configure";
          };

          dhcp = lib.mkOption {
            type        = lib.types.bool;
            default     = true;
            description = "Use DHCP (true) or static IP (false)";
          };

          address = lib.mkOption {
            type        = lib.types.str;
            default     = "";
            description = "Static IP address (only if dhcp = false)";
          };

          gateway = lib.mkOption {
            type        = lib.types.str;
            default     = "";
            description = "Gateway (only if dhcp = false)";
          };
        };
      };
    };

    config =
      let
        cfg = config.connectivity;
      in
      lib.mkMerge [
        (lib.mkIf cfg.bluetooth {
          hardware.bluetooth = {
            enable       = true;
            powerOnBoot  = true;
            settings = {
              General = {
                Experimental    = true;
                FastConnectable = true;
              };
              Policy.AutoEnable = true;
            };
          };
          services.blueman.enable        = true;
          environment.systemPackages     = [ pkgs.bluez ];
        })

        (lib.mkIf cfg.managed.enable {
          assertions =
            [
              {
                assertion = cfg.managed.interface != "";
                message   = "connectivity.managed.interface must be set";
              }
            ]
            ++ lib.optionals (!cfg.managed.dhcp) [
              {
                assertion = cfg.managed.address != "";
                message   = "Static IP requires connectivity.managed.address";
              }
              {
                assertion = cfg.managed.gateway != "";
                message   = "Static IP requires connectivity.managed.gateway";
              }
            ];

          networking = {
            useNetworkd  = true;
            enableIPv6   = true;
          };
          services.resolved.enable = true;

          systemd.network.networks =
            lib.optionalAttrs cfg.managed.dhcp {
              "10-dhcp-wired" = {
                matchConfig.Name = cfg.managed.interface;
                networkConfig.DHCP = "yes";
                dhcpV4Config = {
                  ClientIdentifier    = "mac";
                  UseDomains          = true;
                  CriticalConnection  = true;
                };
              };
            }
            // lib.optionalAttrs (!cfg.managed.dhcp) {
              "10-static-wired" = {
                matchConfig.Name   = cfg.managed.interface;
                networkConfig.DHCP = "no";
                address            = [ cfg.managed.address ];
                gateway            = [ cfg.managed.gateway ];
                dns                = [ cfg.managed.gateway ];
              };
            };
        })

        (lib.mkIf cfg.wireless {
          networking.networkmanager = {
            enable       = lib.mkForce true;
            wifi.backend = "wpa_supplicant";
          };
          systemd.services.NetworkManager-wait-online.enable = false;
          users.users.${config.username}.extraGroups = [ "networkmanager" ];
        })
      ];
  };
}