{self, ...}: {
  flake.nixosConfigurations.rpi-test = self.lib.mkRpiHost {
    hostname = "rpi-test";

    modules = [
      ({pkgs, ...}: {
        system.stateVersion = "26.05";
        username="pete";
        hostname="rpi-test";
        environment.systemPackages = with pkgs; [
          kitty.terminfo
          git
        ];
        # This board's USB disk.
        ssh.server.passwordlogin=true;
        fileSystems."/data" = {
          device = "/dev/disk/by-label/NIXOS_HDD";
          fsType = "ext4";
          options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=120"];
        };
      })
    ];
  };
}