{inputs, ...}: {
  flake.nixosModules.hardware-cachyosKernel = {
    config,
    lib,
    pkgs,
    ...
  }: let
    kernel =
      inputs.nix-cachyos-kernel.packages.${pkgs.stdenv.hostPlatform.system}.linux-cachyos-latest-zen4;
    kernelPackages = pkgs.linuxPackagesFor kernel;
  in {
    options.cachyosKernel = lib.mkEnableOption "Enable cachyos kernel";
    config= lib.mkIf config.cachyosKernel{
      boot.kernelPackages = kernelPackages;
      boot.extraModulePackages = [kernelPackages.r8125];
    };
  };
}
