{
  self,
  lib,
  pkgs,
  settings,
  ...
}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "@wheel"];
  };

  imports = [
    self.nixosModules.nixbuilder
    self.nixosModules.sops
  ];

  nixbuilder.cache.client.enable = true;

  time.timeZone = settings.timeZone;
  i18n.defaultLocale = settings.locale;
  networking.useDHCP = lib.mkDefault true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = settings.sshKeys == [];
    };
  };

  users.users.${settings.username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = settings.sshKeys;
    initialPassword = settings.initialPassword;
  };
  environment.systemPackages = with pkgs; [git vim htop];
  system.stateVersion = settings.stateVersion;
}
