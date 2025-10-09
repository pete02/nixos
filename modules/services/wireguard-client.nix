{ lib, config, ... }:
{
  options = {
    enable.wireguardclient = lib.mkEnableOption "enables wireguard client";
  };
  config = lib.mkIf config.enable.wireguardclient {
    networking.firewall.allowedUDPPorts = [ 51820 ];

    networking.useNetworkd = true;

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

          PrivateKeyFile = "/etc/wireguard/private.key";
          RouteTable = "main";

          FirewallMark = 42;
        };
        wireguardPeers = [
          {
            # laptop wg conf
            PublicKey = "gmynMSFD+1ThqA0YimZdJa4rtZ3BnpsXpV4A/AFJpzo=";
            AllowedIPs = [
              "192.168.88.0/24"
            ];
            Endpoint = "46.173.233.75:13231";
            PersistentKeepalive = 25;
          }
        ];
      };
    };

  };

}
