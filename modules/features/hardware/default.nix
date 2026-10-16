{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.hardware = {
    imports = with self.nixosModules; [
      hardware-gpus
      hardware-cachyosKernel
      hardware-peripherals
      hardware-mdadm
      hardware-gpucooler
    ];
  };
}
