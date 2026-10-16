{lib, ...}: {
  config.flake.lib.mkScript = pkgs: {
    name,
    src,
    runtimeInputs ? [],
    substitutions ? {},
    checkSetup ? "",
  }: let
    script = pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text =
        lib.replaceStrings
        (map (k: "@${k}@") (builtins.attrNames substitutions))
        (builtins.attrValues substitutions)
        (builtins.readFile src);
    };
  in
    pkgs.runCommand "${name}-checked" {} ''
      ${checkSetup}
      # Empty PATH: only runtimeInputs are visible, so the script's
      # own check() proves every command it needs was declared.
      env -i PATH=/var/empty ${script}/bin/${name} --check
      mkdir -p $out/bin
      ln -s ${script}/bin/${name} $out/bin/${name}
    '';
}
