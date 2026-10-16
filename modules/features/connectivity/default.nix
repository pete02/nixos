{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.connectivity = {
    imports = with self.nixosModules; [
      connectivity-bluetooth
      connectivity-wifi
      connectivity-wired
      connectivity-wireguard
    ];
  };
}
