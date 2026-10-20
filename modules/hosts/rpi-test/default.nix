{self, ...}: {
  flake.nixosConfigurations.rpi-test = self.lib.mkRpiHost {
    hostname = "rpi-test";

    modules = [
      ({...}: {
        system.stateVersion = "26.05";

        users.users.pete = {
          isNormalUser = true;
          extraGroups = ["wheel"];
          hashedPassword = "$y$j9T$TmPTe900bU5OQC/V6x/uq0$mPQovyEAf56tAioAtgMr3FbXaF69/DSPQEm.z0Myzc1";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5ukVlkjndCUz16g+8ZJj8Qmr4gmrRzH2cteJYnFF7M raysha"
          ];
        };

        # This board's USB disk.
        fileSystems."/data" = {
          device = "/dev/disk/by-label/NIXOS_HDD";
          fsType = "ext4";
          options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=120"];
        };
      })
    ];
  };
}