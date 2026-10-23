{...}: {
  flake.nixosModules.dev-git = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.dev.git = lib.mkEnableOption "enables git client";

    config = lib.mkIf (config.dev.git) {
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
          user git
      '';
    };
  };
}
