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

      common-tools.books = true;

      services = {
        cleaner = true;
        sambaServer = true;
        sshServer = true;
      };
    };
}
