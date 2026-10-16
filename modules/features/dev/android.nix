{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.dev-android = {
    lib,
    config,
    pkgs,
    ...
  }: {
    options.dev.android = lib.mkEnableOption "Enables android development env";
    config = lib.mkIf config.dev.android {
      services.udev.packages = with pkgs; [
        android-tools
      ];
      users.users.${config.username}.extraGroups = ["adbusers"];
    };
  };
}
