{self,inputs,...}:{
  flake.nixosModules.connectivity-mDNS={config, lib, ...}:{
     options = {
      connectivity.mDNS = lib.mkEnableOption "bluetooth";
    };

    config =lib.mkIf (config.services.mDNS) {
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          addresses = true;
          enable = true;
        };
      };
      };
  };
}