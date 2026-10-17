{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.hardware = {
    imports = with self.nixosModules; [
      hardware-gpus
      hardware-cachyoskernel
      hardware-peripherals
      hardware-mdadm
      hardware-gpucooler
    ];
  };
}
