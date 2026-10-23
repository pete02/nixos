{...}: {
  flake.nixosModules.connectivity-wireguard = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options = {
      connectivity.wireguard = lib.mkEnableOption "wireguard";
    };

    config = lib.mkIf config.connectivity.wireguard {
      sops.secrets."services/wireguard/private_key" = {
        owner = "systemd-network";
        group = "systemd-network";
        mode = "0400";
      };

      networking.firewall.allowedUDPPorts = [51820];
      networking.networkmanager.unmanaged = ["wg0"];
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

            PrivateKeyFile = config.sops.secrets."services/wireguard/private_key".path;
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
    };
  };
}
