{ lib, config, ... }:
{
  options = {
    enable.virtual = lib.mkEnableOption "enable virtual box";
  };
  config = lib.mkIf config.enable.virtual {
    virtualisation.virtualbox.host.enable = true;
    virtualisation.virtualbox.host.enableExtensionPack = true;
    virtualisation.virtualbox.guest.enable = true;
    virtualisation.virtualbox.guest.dragAndDrop = true;

    users.groups.libvirtd.members = [ "pete" ];
    virtualisation.spiceUSBRedirection.enable = true;
    virtualisation.libvirtd.enable = true;
  };
}
