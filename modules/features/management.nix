{
  self,
  inputs,
  system,
  ...
}: {
  flake.nixosModules.management = {
    config,
    lib,
    pkgs,
    system,
    ...
  }: {
    options = {
      management = {
        gitClient = lib.mkEnableOption "enables git client";
        powersave = lib.mkEnableOption "Enable power saving";
        ld = lib.mkEnableOption "enables nix-ld";
      };
    };
    config = lib.mkMerge [
      (lib.mkIf (config.management.powersave) {
        environment.systemPackages = with pkgs; [
          tlp
        ];

        services.thermald.enable = true;

        services.tlp = {
          settings = {
            CPU_BOOST_ON_AC = 1;
            CPU_BOOST_ON_BAT = 0;
            CPU_SCALING_GOVERNOR_ON_AC = "performance";
            CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          };
        };
      })
      (lib.mkIf (config.management.ld) {
        programs.nix-ld = {
          enable = true;
          libraries = with pkgs; [
            stdenv.cc.cc
            zlib
            glibc
            libgcc
            libffi
            openssl
          ];
        };
      })

      (lib.mkIf (config.management.gitClient) {
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
      })

    ];
  };
}
