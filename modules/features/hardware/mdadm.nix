{inputs, ...}: {
  flake.nixosModules.hardware-mdadm = {
    config,
    pkgs,
    lib,
    ...
  }: {
    options.filesystems.mdadm=lib.mkEnableOption "enables MDADM";
    config= lib.mkIf config.filesystems.mdadm{
      environment.systemPackages = with pkgs; [
        mdadm
      ];
    };
  };
}
