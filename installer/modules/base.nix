{ lib, pkgs, settings, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
  };

  time.timeZone = settings.timeZone;
  i18n.defaultLocale = settings.locale;
  networking.useDHCP = lib.mkDefault true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      # Allow password SSH only when no keys are configured, so you can't lock yourself out.
      PasswordAuthentication = settings.sshKeys == [ ];
    };
  };

  users.users.${settings.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = settings.sshKeys;
    initialPassword = settings.initialPassword;
  };

  environment.systemPackages = with pkgs; [ git vim htop ];

  system.stateVersion = settings.stateVersion;
}
