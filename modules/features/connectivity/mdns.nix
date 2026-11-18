{...}: {
  flake.nixosModules.connectivity-mDNS = {
    config,
    lib,
    ...
  }: {
    options = {
      connectivity.mDNS = lib.mkEnableOption "bluetooth";
    };

    config = lib.mkIf (config.connectivity.mDNS) {
      services.avahi = {
        enable = true;
        nssmdns4 = true;

        allowInterfaces = lib.mkIf (config.connectivity.wireguard != {}) (
          lib.attrNames config.connectivity.wireguard
        );
      };
    };
  };
}
