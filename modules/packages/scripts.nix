{
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    ...
  }: let
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
    };
  in {
    packages = scripts;
  };
}