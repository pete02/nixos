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
    imports =[
      self.nixosModules.plasmaBigscreen
    ];

    connectivity = {
      bluetooth = false;
      wireless = true;
      wifiSsid = "Pete";
    };

    management = {
      gitClient = true;
      sshClient = true;
    };
    nixbuilders.usesBuilders = true;
    services.mDNS = true;
  };
}
