{self, ...}: {
  flake.nixosModules.streaming = {
    imports = with self.nixosModules; [
      streaming-sunshine
      streaming-desktops
    ];
  };
}
