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

      scripts = {
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
      };

    in
    {
      flake.packages.x86_64-linux = scripts;
    };
}
