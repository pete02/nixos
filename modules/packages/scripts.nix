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


      sync = mkScript {
        name = "sync";
        src = ../../scripts/sync.sh;

        runtimeInputs = with pkgs; [
          rsync
        ];
      };
    };
  in {
    packages = scripts;
  };
}
