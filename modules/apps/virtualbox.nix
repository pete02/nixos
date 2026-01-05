{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    enable.virtual = lib.mkEnableOption "enable virtual box";
  };
  config = lib.mkIf config.enable.virtual {
    virtualisation.libvirtd = {
      enable = true;
      qemu.ovmf.enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
    };

    users.users.pete.extraGroups = [ "libvirtd" ];
    environment.systemPackages = [ pkgs.virt-manager ];

    boot.kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];
  };
}
