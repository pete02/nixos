{ self, inputs, ... }: {
  flake.nixosModules.ariaConfiguration =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      imports = [
        self.nixosModules.sops
        self.nixosModules.dev
        self.nixosModules.common
      ];

      environment.systemPackages = with pkgs; [
        mdadm
      ];

      username = "pete";
      hostname = "aria";

      management.ld = true;
      management.gitClient = true;

      common-tools.books = true;

      services = {
        cleaner = true;
        sambaServer = true;
        mDNS = true;
        gitops = true;
        sshServer = true;
      };
    };
}
