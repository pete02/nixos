{
  config,
  pkgs,
  lib,
  ...
}:

{
  options = {
    services.enable.vms = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable VMs";
    };
  };
  config = lib.mkIf config.enable.vms {
    #### Enable hardware virtualization
    boot.kernelModules = [
      "kvm-intel"
      "kvm-amd"
    ];

    #### libvirt / QEMU
    virtualisation.libvirtd = {
      enable = true;

      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;

        swtpm.enable = true; # TPM support (useful for modern OSes)
        ovmf.enable = true; # UEFI support
      };
    };

    #### Networking for VMs (NAT, default libvirt network)
    networking.firewall.trustedInterfaces = [ "virbr0" ];

    #### Useful VM tools
    environment.systemPackages = with pkgs; [
      virt-manager
      virt-viewer
      spice
      spice-gtk
      win-virtio
      dnsmasq
    ];

    #### Allow your user to manage VMs
    users.users.${config.username}.extraGroups = [
      "libvirtd"
      "kvm"
    ];

    #### Polkit for virt-manager
    security.polkit.enable = true;

    #### Recommended sysctl tuning
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

  };
}
