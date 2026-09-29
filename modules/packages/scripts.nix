{lib, ...}: {
  perSystem = {pkgs, ...}: let
    mkScript = {
      name,
      src,
      runtimeInputs ? [],
      substitutions ? {},
    }: let
      script = pkgs.writeShellApplication {
        inherit name runtimeInputs;

        text = lib.replaceStrings (map (name: "@${name}@") (
          builtins.attrNames substitutions
        )) (builtins.attrValues substitutions) (builtins.readFile src);
      };
    in
      pkgs.runCommand "${name}-checked" {} ''
        echo "Checking ${name}..."

        if ! ${script}/bin/${name} --check; then
          echo "ERROR: ${name} dependency check failed"
          exit 1
        fi

        mkdir -p "$out/bin"
        ln -s ${script}/bin/${name} "$out/bin/${name}"
      '';

    scripts = rec {
      # Everything from your existing `scripts = rec { ... };`
      # goes here unchanged.
      raysha-filter = mkScript {
        name = "raysha-filter";
        src = ../../scripts/agh-filter.sh;

        runtimeInputs = with pkgs; [
          curl
          jq
          logger
          glibc.getent
          gawk
        ];

        substitutions = {
          CLIENT_NAME = "raysha.local";
          CLIENT_MAC = "88:d8:2e:ba:62:29";
        };
      };

      alanna-filter = mkScript {
        name = "alanna-filter";
        src = ../../scripts/agh-filter.sh;

        runtimeInputs = with pkgs; [
          curl
          jq
          logger
          glibc.getent
          gawk
        ];

        substitutions = {
          CLIENT_NAME = "alanna.local";
          CLIENT_MAC = "2C:CF:67:DA:15:86";
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
          coreutils
          findutils
          git
          gnugrep
          inetutils
          nixos-rebuild
          nvd
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
          logger
          raysha-filter
          alanna-filter
        ];

        substitutions = {
          STATE_DIR = "/var/lib/samba-timelock";
          COOLDOWN_SECS = "${toString (72 * 60 * 60)}";
          CUTOFF_HOUR = "${toString 22}";
        };
      };

      samba-timelock-postexec = mkScript {
        name = "samba-timelock-postexec";
        src = ../../scripts/samba-timelock-postexec.sh;

        runtimeInputs = with pkgs; [
          samba
          logger
          coreutils
          raysha-filter
          alanna-filter
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
          logger
          coreutils
          raysha-filter
          alanna-filter
        ];

        substitutions = {
          STATE_DIR = "/var/lib/samba-timelock";
          SHARE_NAME = "timelock";
          MAX_SESSION_SECS = "${toString (90 * 60)}";
          CUTOFF_HOUR = "${toString 22}";
        };
      };
    };
  in {
    packages = scripts;
  };
}
