
{...}: {
  flake.nixosModules.connectivity-wireguard = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.connectivity.wireguard;
  in {
    options.connectivity.wireguard = lib.mkOption {
      description = "WireGuard site configurations.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          endpoint = lib.mkOption {
            type = lib.types.str;
            description = "WireGuard peer endpoint.";
          };

          allowed_ips = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Allowed IP ranges for the peer.";
          };

          address = lib.mkOption {
            type = lib.types.str;
            description = "Local WireGuard interface address.";
          };
        };
      });
    };

    config = lib.mkIf (cfg != {}) {
      sops.secrets = lib.mapAttrs' (site: _: 
        lib.nameValuePair "wireguard/${site}/private_key" {
          key = "wireguard.${site}.private_key";
          owner = "systemd-network";
          group = "systemd-network";
          mode = "0400";
        }
      ) cfg;

      networking.firewall.allowedUDPPorts = [51820];
      networking.networkmanager.unmanaged = ["wg0"];
      networking.useNetworkd = true;
      environment.systemPackages = [pkgs.wireguard-tools];

      systemd.network = {
        enable = true;

        networks."50-wg0" = {
          matchConfig.Name = "wg0";
          address = lib.mapAttrsToList (_: site: site.address) cfg;
        };

        netdevs."50-wg0" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = "wg0";
          };

          wireguardConfig = {
            ListenPort = 51820;
            PrivateKeyFile = config.sops.secrets."wireguard/${builtins.head (builtins.attrNames cfg)}/private_key".path;
            RouteTable = "main";
            FirewallMark = 42;
          };

          wireguardPeers = lib.mapAttrsToList (site: settings: {
            PublicKeyFile = config.sops.secrets."wireguard/${site}/public_key".path;
            AllowedIPs = settings.allowed_ips;
            Endpoint = settings.endpoint;
            PersistentKeepalive = 25;
          }) cfg;
        };
      };
    };
  };
}
