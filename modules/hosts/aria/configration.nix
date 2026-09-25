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
