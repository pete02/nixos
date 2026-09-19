{inputs, ...}: {
  flake.nixosModules.mdadm = {
    config,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      mdadm
    ];
  };
}
