{self, inputs, ...}:{
  flake.nixosModules.connectivity = {lib, config, pkgs, ...}:{
    options = {
      connectivity={
        bluetooth = lib.mkEnableOption "enable bluetooth";
        wireless= lib.mkEnableOption "enable wireless";
        managed= {
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
    };

    config= lib.mkMerge[
        (lib.mkIf config.connectivity.bluetooth {
          services.blueman.enable = true;
          environment.systemPackages = [ pkgs.bluez ];
          hardware.bluetooth = {
            enable = true;
            powerOnBoot = true;
            settings = {
              General = {
                Experimental = true;
                FastConnectable = true;
              };
              Policy = {
                AutoEnable = true;
              };
            };
          };
        })
        (lib.mkIf config.connectivity.managed.enabled {
          assertions = [
            {
              assertion = config.connectivity.managed.interface != "";
              message = "networking.custom.interface must be provided";
            }
          ]
          ++ lib.optionals (!config.connectivity.managed.dhcp) [
            {
              assertion = config.connectivity.managed.address != "";
              message = "Static IP requires address";
            }
            {
              assertion = config.connectivity.managed.gateway != "";
              message = "Static IP requires gateway";
            }
          ];

          networking.useNetworkd = true;
          networking.enableIPv6 = true;
          services.resolved.enable = true;

          systemd.network.networks."10-dhcp-wired" = lib.mkIf config.connectivity.managed.dhcp {
            matchConfig.Name = "${config.connectivity.managed.interface}";
            networkConfig.DHCP = "yes";
            dhcpConfig = {
              ClientIdentifier = "mac";
              UseDomains = "true";
              CriticalConnection = "true";
            };
          };

          systemd.network.networks."10-static-wired" = lib.mkIf (!config.connectivity.managed.dhcp) {
            matchConfig.Name = "${config.connectivity.managed.interface}";
            networkConfig.DHCP = "no";
            address = [ config.connectivity.managed.address ];
            gateway = [ config.connectivity.managed.gateway ];
            dns = [ config.connectivity.managed.gateway ];
          };
        })

        (lib.mkIf config.connectivity.wireless {
          networking.networkmanager.enable = lib.mkForce true;
          networking.networkmanager.wifi.backend = "wpa_supplicant";
          systemd.services.NetworkManager-wait-online.enable = false;
          users.users.${config.username}.extraGroups = [ "networkmanager" ];
        })
     ]; 
  };
}