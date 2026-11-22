{inputs, ...}: {
  flake.nixosModules.dev-tools = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.dev;
  in {
    options.dev = {
      enable = lib.mkEnableOption "development tools (nix tooling, direnv, container runtime)";
      enableOnBoot = lib.mkEnableOption "Enables docker/podman on boot"
      ld = lib.mkEnableOption "Enable ld tooling";
      vscode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install VS Code and use it as the SOPS editor.";
      };

      podman.enable = lib.mkEnableOption "Podman (Docker-compatible) instead of Docker";
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
      # ── Core tooling ────────────────────────────────────────────────────
      {
        environment.systemPackages = with pkgs; [
          nixd
          nixfmt-tree
          nvd
          vulnix
          jq
          zip
        ];

        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        nix = {
          nixPath = ["nixpkgs=${inputs.nixpkgs}"];
          settings.trusted-users = ["root" config.username];
        };
      }

      # ── Editor ──────────────────────────────────────────────────────────
      (lib.mkIf cfg.vscode {
        environment.systemPackages = [pkgs.vscode];
        environment.variables.SOPS_EDITOR = "code --wait";
      })

      # ── Containers: Docker (default) ────────────────────────────────────
      (lib.mkIf (!cfg.podman.enable) {
        virtualisation.docker = {
          enable = true;
          enableOnBoot= enableOnBoot;
          daemon.settings = {
            features.cdi = true;
            registry-mirrors = ["http://aria.local:5001"];
            insecure-registries = ["aria.local:5001"];
          };
        };

        users.users.${config.username}.extraGroups = ["docker"];
        systemd.services.docker.wantedBy = lib.mkForce [];
      })

      # ── Containers: Podman ──────────────────────────────────────────────
      (lib.mkIf cfg.podman.enable {
        virtualisation.podman = {
          enable = true;
          enableOnBoot = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };

        environment.systemPackages = [pkgs.podman-compose];
      })

      (lib.mkIf (cfg.ld) {
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
    ]);
  };
}
