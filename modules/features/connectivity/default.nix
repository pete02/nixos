{self, ...}: {
  flake.nixosModules.connectivity = {
    imports = with self.nixosModules; [
      connectivity-bluetooth
      connectivity-wifi
      connectivity-mDNS
      connectivity-wired
      connectivity-wireguard
    ];
  };
}
