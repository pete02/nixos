{ self, inputs, ... }: {
  flake.nixosModules.dev =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      options = {
        podman = {
          enable = lib.mkEnableOption "Podman container runtime (Docker-compatible)";
        };
      };

      config = lib.mkMerge [
        ({
          # Development tools
          environment.systemPackages = with pkgs; [
            nixd
            vscode
            direnv
          ];

          # Nix configuration
          nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
          nix.settings = {
            trusted-users = [
              "root"
              config.username
            ];
          };
        })
        # Docker (default) or Podman (if enabled)
        (lib.mkIf (!config.podman.enable) {
          # Docker is the default container runtime
          virtualisation.docker = {
            enable = true;
            enableOnBoot = false;
            daemon.settings = {
              features = {
                cdi = true;
              };
            };
          };

          users.users.${config.username} = {
            extraGroups = [ "docker" ];
          };
        })

        (lib.mkIf config.podman.enable {
          # Podman overrides Docker when enabled
          virtualisation.containers.enable = true;
          virtualisation = {
            podman = {
              enable = true;
              dockerCompat = true;
              defaultNetwork.settings.dns_enabled = true;
            };
          };

          users.users.${config.username} = {
            extraGroups = [ "podman" ];
          };

          environment.systemPackages = with pkgs; [
            podman
            podman-compose
          ];
        })
      ];
    };
}
