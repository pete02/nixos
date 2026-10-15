{inputs, ...}: {
  flake.nixosModules.cachyosKernel = {
    config,
    lib,
    pkgs,
    ...
  }: let
    kernel =
      inputs.nix-cachyos-kernel.packages.${pkgs.stdenv.hostPlatform.system}.linux-cachyos-latest-zen4;
    kernelPackages = pkgs.linuxPackagesFor kernel;
  in {
    boot.kernelPackages = kernelPackages;
    boot.extraModulePackages = [kernelPackages.r8125];
  };
}
