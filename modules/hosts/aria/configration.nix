{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.ariaConfiguration = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.sops
      self.nixosModules.dev
      self.nixosModules.common
      self.nixosModules.mdadm
    ];

    username = "pete";

    management.ld = true;
    management.gitClient = true;

    common-tools.books = true;

    environment.sessionVariables = {
      MAILADDR = "petrik.rasanen@gmail.com";
    };

    services.health-check = {
      enable = true;
      devices = ["/dev/sda" "/dev/sdb" "/dev/nvme0n1"];
      bcachefs = {
        enable = true;
        devices = [
          "sda"
          "sdb1"
          "nvme0n1p2"
        ];
      };
    };


    services.bitwarden-backup = {
      enable = true;
      dataDir =  "/mnt/server/Serversetup/data/vaultwarden";
      ntfyUrl="https://ntfy.lumilukko.com/Aria";
      rcloneConfigFile = config.sops.secrets.rclone-gdrive-config.path;
    };

    environment.systemPackages = with pkgs; [
      kitty.terminfo
    ];

    services = {
      cleaner = true;
      sambaServer = true;
      sambaTimelock = true;
      gitops = true;
      mDNS = true;
    };
  };
}
