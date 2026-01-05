{ lib, config, ... }:
{
  options = {
    enable.virtual = lib.mkEnableOption "enable virtual box";
  };
  config = lib.mkIf config.enable.virtual {
    virtualisation.virtualbox.host.enable = true;
    virtualisation.virtualbox.host.enableExtensionPack = true;
    users.extraGroups.vboxusers.members = [ "pete" ];

  };
}
