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
    programs.dconf.enable = true;

    users.users.pete.extraGroups = [ "libvirtd" ];

    environment.systemPackages = with pkgs; [
      virt-manager
      virt-viewer
      spice
      spice-gtk
      spice-protocol
      win-virtio
      win-spice
      gnome.adwaita-icon-theme
    ];

    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          swtpm.enable = true;
          ovmf.enable = true;
          ovmf.packages = [ pkgs.OVMFFull.fd ];
        };
      };
      spiceUSBRedirection.enable = true;
    };
    services.spice-vdagentd.enable = true;
  };
}
