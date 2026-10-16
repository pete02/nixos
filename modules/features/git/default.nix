{self,inputs,...}:{
  flake.nixosModules.git={
    config,lib,pkgs,...
  }:{
    options.git=lib.mkEnableOption "enables git client";
    
    config=lib.mkIf (config.git) {
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