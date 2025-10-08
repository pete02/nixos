{
  pkgs,
  ...
}:

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

  networking.hostName = "aria"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Europe/Helsinki";
  nixpkgs.config.allowUnfree = true;
  users.users.pete = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcUoZ1iRFqNMy/cf3aVsvEmnwysuK8CAm1dHi6DbskN pete"
    ];
    packages = with pkgs; [
      tree
    ];
  };

  enable = {
    nvidia = true;
    docker = true;
    routersamba = true;
  };
  services.enable = {
    ssh = true;
    gitops = true;
  };
  username = "pete";
  update-script = pkgs.writeShellScriptBin "update" ''
    sudo systemctl start gitops.service
    sudo systemctl status gitops.service
  '';

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    update-script
    git
    lshw
  ];



  services.samba = {
    
    settings = {
      "tm_share" = {
          "path" = "/mnt/Shares/tm_share";
          "valid users" = "username";
          "public" = "no";
          "writeable" = "yes";
          "force user" = "username";
          "fruit:aapl" = "yes";
          "fruit:time machine" = "yes";
          "vfs objects" = "catia fruit streams_xattr";
      };
    };
  };

  system.stateVersion = "25.05"; # Did you read the comment?

}
