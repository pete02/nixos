{ inputs, ... }:
{
  flake.nixosModules.cachyosKernel = { config, lib, pkgs, ... }:
  let
    kernel = inputs.nix-cachyos-kernel.packages.${pkgs.stdenv.hostPlatform.system}.linux-cachyos-latest-zen4;
    kernelPackages = pkgs.linuxPackagesFor kernel;
  in
  {
    nix.settings.substituters        = [ "https://attic.xuyh0120.win/lantian" ];
    nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];

    boot.kernelPackages = kernelPackages;
    boot.extraModulePackages = [ kernelPackages.r8125 ];
  };
}