{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.dev-virtualization = {
    pkgs,
    config,
    lib,
    ...
  }: {
    options.virtualization = lib.mkEnableOption "enables virtualization";
    config = lib.mkIf config.virtualization {
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
        };
      };

      networking.firewall.trustedInterfaces = ["virbr0"];

      environment.systemPackages = with pkgs; [
        virt-manager
        virt-viewer
        spice
        spice-gtk
        virtio-win
        dnsmasq
      ];
      users.users.${config.username}.extraGroups = [
        "libvirtd"
        "kvm"
      ];
      security.polkit.enable = true;
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
      };
    };
  };
}
