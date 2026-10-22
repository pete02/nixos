{self, ...}: {
  flake.nixosConfigurations.tress = self.lib.mkRpiHost {
    hostname = "tress";

    modules = [
      ({pkgs, ...}: {
        system.stateVersion = "26.05";
        username = "pete";
        hostname = "tress";
        nixbuilder.cache.client = {
          enable = true;
          url = "http://192.168.88.241:8080/main";
          publicKey = "main:i1t81gc6fOtVfDvKgpiL1LG5HjrWF7AtHD21rmbr1OI=";
          pullTokenSecret = "services/attic/pull_token";
        };
        connectivity.wifi = {
          enable = true;
          Ssid = "Pete";
        };
        environment.systemPackages = with pkgs; [
          kitty.terminfo
          git
        ];
        # This board's USB disk.
        ssh.server.passwordlogin = true;
        fileSystems."/data" = {
          device = "/dev/disk/by-label/NIXOS_HDD";
          fsType = "ext4";
          options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=120"];
        };
      })
    ];
  };
}
