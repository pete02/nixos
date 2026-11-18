{...}: {
  flake.nixosModules.base-git = {
    config,
    lib,
    pkgs,
    ...
  }: {
    config = {
      environment.systemPackages = [
        pkgs.git
      ];
      sops.secrets."services/github" = {
        owner = config.username;
      };
      sops.secrets."services/forgejo" = {
        owner = config.username;
      };
      environment.etc."ssh/ssh_config".text = ''
        Host github.com
          hostname github.com
          identityFile /run/secrets/services/github
          user git
        Host git.lumilukko.com
          HostName git.lumilukko.com
          Port 2222
          User git
          identityFile /run/secrets/services/forgejo
      '';

      programs.ssh.knownHosts."git.lumilukko.com" = {
        hostNames = ["[git.lumilukko.com]:2222"];
        publicKey = "sh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4VxwBxMFF+tA8x3WdsXZ54/PZsTQ4IPdFjDig6wpJk"; # from: ssh-keyscan -p 2222 -t ed25519 git.lumilukko.com
      };
    };
  };
}
