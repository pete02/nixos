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

    username = "pete";

    management.ld = true;
    git=true;

    common-tools.books = true;

    environment.sessionVariables = {
      MAILADDR = "petrik.rasanen@gmail.com";
    };

    health-check = {
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

    bitwardenBackup = {
      enable = true;
      dataDir = "/mnt/server/Serversetup/data/vaultwarden";
      containerName = "vaultwarden";
      ntfyUrl = "https://ntfy.lumilukko.com/Aria";
      rcloneConfigFile = config.sops.secrets.rclone-gdrive-config.path;
    };

    environment.systemPackages = with pkgs; [
      kitty.terminfo
    ];

    sambaTimelock.server=true;
    samba.server=true;


    services = {
      cleaner = true;
      gitops = true;
      mDNS = true;
    };
  };
}
