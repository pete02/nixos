{lib, ...}: {
  perSystem = {pkgs, ...}: let
    mkScript = {
      name,
      src,
      runtimeInputs ? [],
      substitutions ? {},
      checkSetup ? "",
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

        ${checkSetup}

        if ! ${script}/bin/${name} --check; then
          echo "ERROR: ${name} dependency check failed"
          exit 1
        fi

        mkdir -p "$out/bin"
        ln -s ${script}/bin/${name} "$out/bin/${name}"
      '';

    scripts = rec {
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
    };
  in {
    packages = scripts;
  };
}
