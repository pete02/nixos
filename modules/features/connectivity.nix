{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.connectivity = {
    lib,
    config,
    pkgs,
    ...
  }: {
    options = {
      connectivity = {
        bluetooth = lib.mkEnableOption "bluetooth";
        wireless = lib.mkEnableOption "wireless via NetworkManager";
        wireguard = lib.mkEnableOption "enables wireguard client";

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

    config = let
      cfg = config.connectivity;
    in
      lib.mkMerge [
        (lib.mkIf cfg.bluetooth {
          hardware.bluetooth = {
            enable = true;
            powerOnBoot = true;
            settings = {
              General = {
                Experimental = true;
                FastConnectable = true;
              };
              Policy.AutoEnable = true;
            };
          };
          services.blueman.enable = true;
          environment.systemPackages = [pkgs.bluez];
        })

        (lib.mkIf cfg.managed.enable {
          assertions =
            [
              {
                assertion = cfg.managed.interface != "";
                message = "connectivity.managed.interface must be set";
              }
            ]
            ++ lib.optionals (!cfg.managed.dhcp) [
              {
                assertion = cfg.managed.address != "";
                message = "Static IP requires connectivity.managed.address";
              }
              {
                assertion = cfg.managed.gateway != "";
                message = "Static IP requires connectivity.managed.gateway";
              }
            ];

          networking = {
            useNetworkd = true;
            enableIPv6 = true;
          };
          services.resolved.enable = true;

          systemd.network.networks =
            lib.optionalAttrs cfg.managed.dhcp {
              "10-dhcp-wired" = {
                matchConfig.Name = cfg.managed.interface;
                networkConfig.DHCP = "yes";
                dhcpV4Config = {
                  ClientIdentifier = "mac";
                  UseDomains = true;
                  CriticalConnection = true;
                };
              };
            }
            // lib.optionalAttrs (!cfg.managed.dhcp) {
              "10-static-wired" = {
                matchConfig.Name = cfg.managed.interface;
                networkConfig.DHCP = "no";
                address = [cfg.managed.address];
                gateway = [cfg.managed.gateway];
                dns = [cfg.managed.gateway];
              };
            };
        })

        (lib.mkIf cfg.wireless {
          networking.networkmanager = {
            enable = lib.mkForce true;
            wifi.backend = "wpa_supplicant";
          };
          systemd.services.NetworkManager-wait-online.enable = false;
          users.users.${config.username}.extraGroups = ["networkmanager"];
        })
        (lib.mkIf cfg.wireguard {
          sops.secrets."wireguard/private_key" = {
            owner = config.username;
          };

          networking.firewall.allowedUDPPorts = [51820];

          networking.useNetworkd = true;
          environment.systemPackages = [pkgs.wireguard-tools];
          systemd.network = {
            enable = true;

            networks."50-wg0" = {
              matchConfig.Name = "wg0";

              address = [
                "10.0.0.3/32"
              ];
            };

            netdevs."50-wg0" = {
              netdevConfig = {
                Kind = "wireguard";
                Name = "wg0";
              };

              wireguardConfig = {
                ListenPort = 51820;

                PrivateKeyFile = "/run/secrets/wireguard/private_key";
                RouteTable = "main";

                FirewallMark = 42;
              };
              wireguardPeers = [
                {
                  PublicKey = "gmynMSFD+1ThqA0YimZdJa4rtZ3BnpsXpV4A/AFJpzo=";
                  AllowedIPs = [
                    "192.168.88.0/24"
                  ];
                  Endpoint = "lumilukko.com:13231";
                  PersistentKeepalive = 25;
                }
              ];
            };
          };
        })
      ];
  };
}
