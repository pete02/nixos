{ lib, config, ... }:
{
  options = {
    enable.virtual = lib.mkEnableOption "enable virtual box";
  };
  config = lib.mkIf config.enable.virtual {
    programs.virt-manager.enable = true;

    users.groups.libvirtd.members = [ "pete" ];
    virtualisation.spiceUSBRedirection.enable = true;
    virtualisation.libvirtd.enable = true;
  };
}
