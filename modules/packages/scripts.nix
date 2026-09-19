{
  inputs,
  lib,
  ...
}:

{
  config =
    let
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

      mkScript =
        {
          name,
          src,
          runtimeInputs ? [ ],
          substitutions ? { },
        }:
        let
          script = pkgs.writeShellApplication {
            inherit name runtimeInputs;

            text = lib.replaceStrings (map (name: "@${name}@") (
              builtins.attrNames substitutions
            )) (builtins.attrValues substitutions) (builtins.readFile src);
          };
        in
        pkgs.runCommand "${name}-checked" { } ''
          echo "Checking ${name}..."

          if ! ${script}/bin/${name} --check; then
            echo "ERROR: ${name} dependency check failed"
            exit 1
          fi

          mkdir -p "$out/bin"
          ln -s ${script}/bin/${name} "$out/bin/${name}"
        '';

      scripts = rec {
        raysha-filter = mkScript {
          name = "raysha-filter";
          src = ../../scripts/raysha-filter.sh;

          runtimeInputs = with pkgs; [
            curl
            jq
            glibc.getent
            gawk
          ];

          substitutions = {
            CLIENT_NAME = "raysha.local";
            CLIENT_MAC = "88:d8:2e:ba:62:29";
          };
        };

        gitops = mkScript {
          name = "gitops";
          src = ../../scripts/gitops.sh;

          runtimeInputs = with pkgs; [
            curl
            git
          ];
        };

        gpu-cooler = mkScript {
          name = "gpu-cooler";
          src = ../../scripts/gpu-cooler.sh;

          runtimeInputs = with pkgs; [
            python313Packages.gputil
            gawk
          ];
        };

        rebuild = mkScript {
          name = "rebuild";
          src = ../../scripts/rebuild.sh;

          runtimeInputs = with pkgs; [
            git
            nixos-rebuild
            treefmt
          ];
        };

        sync = mkScript {
          name = "sync";
          src = ../../scripts/sync.sh;

          runtimeInputs = with pkgs; [
            rsync
          ];
        };

        update = mkScript {
          name = "update";
          src = ../../scripts/update.sh;

          runtimeInputs = with pkgs; [
            coreutils
            findutils
            git
            nixos-rebuild
            treefmt
            sudo
            libnotify
          ];

          substitutions = {
            CONFIG_FOLDER = "/etc/nixos";
          };
        };

        samba-timelock-preexec = mkScript {
          name = "samba-timelock-preexec";
          src = ../../scripts/samba-timelock-preexec.sh;

          runtimeInputs = with pkgs; [
            coreutils
            raysha-filter
          ];

          substitutions = {
            STATE_DIR = "/var/lib/samba-timelock";
            COOLDOWN_SECS = "${toString (2 * 60)}";
            CUTOFF_HOUR = "${toString 21}";
          };
        };

        samba-timelock-postexec = mkScript {
          name = "samba-timelock-postexec";
          src = ../../scripts/samba-timelock-postexec.sh;

          runtimeInputs = with pkgs; [
            samba
            coreutils
            raysha-filter
          ];

          substitutions = {
            STATE_DIR = "/var/lib/samba-timelock";
            SHARE_NAME = "timelock";
          };
        };

        samba-timelock-enforce = mkScript {
          name = "samba-timelock-enforce";
          src = ../../scripts/samba-timelock-enforce.sh;

          runtimeInputs = with pkgs; [
            samba
            coreutils
            raysha-filter
          ];

          substitutions = {
            STATE_DIR = "/var/lib/samba-timelock";
            SHARE_NAME = "timelock";
            MAX_SESSION_SECS = "${toString (2* 60)}";
            CUTOFF_HOUR = "${toString 21}";
          };
        };
      };

    in
    {
      flake.packages.x86_64-linux = scripts;
    };
}
