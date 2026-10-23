{
  ...
}: {
  flake.nixosModules.base-settings = {
    lib,
    pkgs,
    config,
    ...
  }: {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
        description = "The username of the main user";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "The hostname of the system";
      };
    };

    config = {
      environment.systemPackages = with pkgs; [
        vim
        git
        tree
        groff
        htop
        unzip
        unrar
        lshw
        libnotify
        fastfetch
      ];
      users.users.${config.username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "seat"
          "dialout"
          "uucp"
        ];
      };

      console.keyMap = "fi";
      time.timeZone = "Europe/Helsinki";
      i18n.defaultLocale = "fi_FI.UTF-8";

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      networking.hostName = config.hostname;

      nixpkgs.config.allowUnfree = true;

      nix.gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };
      nix.settings.auto-optimise-store = true;
    };
  };
}
