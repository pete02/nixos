{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.alannaConfiguration = {
    pkgs,
    lib,
    config,
    ...
  }: {
    username = "pete";

    connectivity = {
      bluetooth = false;
      wireless = true;
      wifiSsid = "Pete";
    };

    management = {
      gitClient = true;
    };

    services.mDNS = true;
  };
}
