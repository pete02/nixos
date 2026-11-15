{...}: {
  flake.nixosModules.connectivity-wifi = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options = {
      connectivity.wifi = {
        enable = lib.mkEnableOption "wireless via NetworkManager";
        backend = lib.mkOption {
          type = lib.types.enum ["iwd" "wpa_supplicant"];
          default = "iwd";
          description = "Wi-Fi backend for NetworkManager";
        };
        Ssid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SSID to autoconnect to on boot";
        };
      };
    };

    config = lib.mkIf config.connectivity.wifi.enable {
      environment.systemPackages = [pkgs.iw];

      networking.networkmanager = {
        enable = lib.mkForce true;
        wifi.backend = config.connectivity.wifi.backend;
      };

      networking.wireless.iwd = {
        enable = true;
        settings = {
          General = {
            Country = "FI";
          };
        };
      };

      systemd.services.NetworkManager-wait-online.enable = false;
      users.users.${config.username or "root"}.extraGroups = ["networkmanager"];

      sops.secrets."wifi/psk" = {};

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
              key-mgmt = "sae";
              psk = "$WIFI_PSK";
            };
            ipv4.method = "auto";
            ipv6.method = "auto";
          };
        };
      };
    };
  };
}
