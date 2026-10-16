{
  self,
  inputs,
  system,
  ...
}: {
  flake.nixosModules.management = {
    config,
    lib,
    pkgs,
    system,
    ...
  }: {
    options = {
      management = {
        powersave = lib.mkEnableOption "Enable power saving";
        ld = lib.mkEnableOption "enables nix-ld";
      };
    };
    config = lib.mkMerge [
      (lib.mkIf (config.management.ld) {
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



    ];
  };
}
