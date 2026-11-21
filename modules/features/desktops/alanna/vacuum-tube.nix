{inputs, ...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    packages.vacuum-tube = pkgs.vacuum-tube.overrideAttrs (old: {
      version = "git-${inputs.vacuum-tube-src.shortRev or "dirty"}";
      src = inputs.vacuum-tube-src;

      # Read deps straight from package-lock.json, so there is no
      # npmDepsHash to update when upstream changes its dependencies.
      npmDeps = pkgs.importNpmLock {npmRoot = inputs.vacuum-tube-src;};
      nativeBuildInputs =
        (lib.remove pkgs.npmHooks.npmConfigHook old.nativeBuildInputs)
        ++ [pkgs.importNpmLock.npmConfigHook];
    });
  };
}
