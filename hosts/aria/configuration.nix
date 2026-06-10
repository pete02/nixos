{
  pkgs,
  ...
}:
let
  update-script = pkgs.writeShellScriptBin "update" ''
    sudo systemctl start gitops.service
    sudo systemctl status gitops.service
  '';
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./boot.nix
    ./../../modules
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "aria";
  time.timeZone = "Europe/Helsinki";
  environment.variables.TERM = "xterm-256color";

  users.users.pete = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdej5cPrmoBbFQVPcj2pFJhScGdfdZJ2dXnaF3fxXJl server@raysha"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIADLIKC7KG2TgvOeEaK5LRKgyTE4tFupPZ1k08nJ1grQ talia"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFfxdS4k6cw7VZ8LT/cyVNhIDmLBoazLyx6n4WcIoeS pete@WIN-O1N1V4FR36K"
    ];
    packages = with pkgs; [
      tree
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    update-script
    git
    rsync
    lshw
    smartmontools
  ];

  smb = {
    enable = true;
    router = true;
  };

  enable = {
    nvidia = true;
    docker = true;
  };

  services.enable = {
    ssh = true;
    gitops = true;
    gpufan = true;
  };

  username = "pete";

  services.samba = {
    enable = true;
    securityType = "user";
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "smbnix";
        "netbios name" = "smbnix";
        "hosts allow" = "192.168.88.0/24 10.0.0.0/24 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      "private" = {
        "path" = "/mnt/private";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "pete";
        "force group" = "users";
      };
    };
  };

  systemd.services.serverbackup = {
    description = "Daily backup of Serversetup/data to router samba";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.rsync}/bin/rsync -avz --delete /mnt/private/Serversetup/data/ /mnt/router/serverbackups/
      '';
    };
  };

  system.stateVersion = "25.05";

}
