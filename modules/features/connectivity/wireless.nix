{self,inputs,...}:{
  flake.nixosModules.connectivity-wifi={config, lib, ...}:{
     options = {
      connectivity.wifi = {
        enable = lib.mkEnableOption "wireless via NetworkManager";
        Ssid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SSID to autoconnect to on boot";
        };
      };
    };

    config =lib.mkIf config.connectivity.wifi.enable {
      networking.networkmanager = {
        enable = lib.mkForce true;
        wifi.backend = "wpa_supplicant";
      };
      systemd.services.NetworkManager-wait-online.enable = false;
      users.users.${config.username}.extraGroups = ["networkmanager"];

      sops.secrets."wifi/psk" = {
      };

      sops.templates."wifi-env".content = ''
        WIFI_PSK=${config.sops.placeholder."wifi/psk"}
      '';

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [config.sops.templates."wifi-env".path];
        profiles = lib.mkIf (config.connectivity.wifi.Ssid != null) {
          home-wifi = {
            connection = {
              id = "home-wifi";
              type = "wifi";
              autoconnect = true;
            };
            wifi = {
              mode = "infrastructure";
              ssid = config.connectivity.wifi.Ssid;
            };
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = "$WIFI_PSK"; # substituted from environmentFiles at activation
            };
            ipv4.method = "auto";
            ipv6.method = "auto";
          };
        };
      };
    };
  };
}