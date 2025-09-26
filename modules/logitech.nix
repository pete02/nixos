{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    enable.logitech = lib.mkEnableOption "Enable Solaar (logitech hub alternative)";
  };
  config = {
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.qemu = true;

    # Install QEMU and virt-manager for GUI
    environment.systemPackages = with pkgs; [
      qemu
      virt-manager
      ovmf # UEFI firmware for Windows VMs
      spice-vdagent
    ];

    # Enable user to access libvirt
    users.groups.libvirt.members = [ "pete" ];
  };
}
