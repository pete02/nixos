{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.sops = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];

    environment.systemPackages = [pkgs.sops];
    sops.defaultSopsFile = "${self}/secrets/secrets.yaml";
    sops.defaultSopsFormat = "yaml";
    sops.age.keyFile = "/etc/sops/age/keys.txt";

    sops.secrets.rclone-gdrive-config = {
      sopsFile = ../../secrets/rclone-gdrive.conf;
      format = "ini";
      key = "";
    };
  };
}
