{inputs, ...}: {
  flake.nixosModules.hardware-mdadm = {
    config,
    pkgs,
    lib,
    ...
  }: {
    options.hardware.mdadm = lib.mkEnableOption "enables MDADM";
    config = lib.mkIf config.hardware.mdadm {
      environment.systemPackages = with pkgs; [
        mdadm
      ];
    };
  };
}
