{pkgs, ...}: {
  hardware.keyboard.qmk.enable = true;
  services.udev.packages = with pkgs; [
    via
  ];

  username = "pete";

  healthcheck = {
    enable = true;
    devices = ["/dev/sda" "/dev/nvme0n1" "/dev/nvme1n1"];
    memSize = "1G";
    mdadm = {
      enable = true;
      devices = ["md127"];
    };
  };

  nixbuilder.cache.client.enable = true;

  connectivity = {
    bluetooth = true;
    mDNS = true;
  };
  ssh.client.enable = true;
  nixos-management.gitops.enable = true;

  samba.clients.server.enable = true;
  samba.clients.timelock.enable = true;

  streaming.podman = {
    enable = true;
    parentInterface = "enp12s0"; # aria's real NIC name

    containers.raysha = {
      ip = "192.168.88.3";
      persistentHome = true;
      homePath = "/var/lib/pete";
      config = {
        system.stateVersion = "26.05";
        username = "pete";
        desktop.desktop = "raysha";
        desktop.monitors = [
          {
            output = "desk-1";
            mode = "3440x1440@175";
          }
        ];
      };
    };
  };
  networking.firewall.allowedTCPPorts = [8080];

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];

  /*
  desktop.desktop = "raysha";
  desktop.monitors = [
    {
      output = "desc:Dell Inc. AW3425DW DD5H274";
      mode = "3440x1440@175";
      bitdepth = 10;
    }
    {
      output = "desc:AOC Q32G1WG4 0x00000669";
      mode = "2560x1440@120";
      position = "3440x0";
    }
  ];
  */
}
