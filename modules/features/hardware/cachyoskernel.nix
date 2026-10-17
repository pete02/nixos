{inputs, ...}: {
  flake.nixosModules.hardware-cachyoskernel = {
    config,
    lib,
    pkgs,
    ...
  }: let
    kernel =
      inputs.nix-cachyos-kernel.packages.${pkgs.stdenv.hostPlatform.system}.linux-cachyos-latest-zen4;
    kernelPackages = pkgs.linuxPackagesFor kernel;
  in {
    options.hardware.cachyos-kernel = lib.mkEnableOption "Enable cachyos kernel";
    config = lib.mkIf config.hardware.cachyos-kernel {
      boot.kernelPackages = kernelPackages;
      boot.extraModulePackages = [kernelPackages.r8125];
    };
  };
}
