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
