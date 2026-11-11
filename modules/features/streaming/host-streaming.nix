{self, ...}: {
  flake.nixosModules.streaming-sunshine = {
    lib,
    pkgs,
    config,
    ...
  }: {
    options.streaming.sunshine = {
      enable = lib.mkEnableOption "Sunshine game streaming";

      desktop = lib.mkOption {
        type = lib.types.str;
        default = "gaming";
        description = ''
          Name of the activated desktop def (config.desktops.<name>) that supplies
          the Hyprland-coupled pieces for host-side Sunshine: EDID/monitor handling,
          csrf origins, and the start/stop/launch wrapper scripts. The Sunshine
          module itself no longer hardcodes any of that.
        '';
      };
    };

    config = lib.mkIf config.streaming.sunshine.enable {
      services.sunshine = {
        enable = true;
        capSysAdmin = true;
        openFirewall = true;

        settings = {
          capture = "kms";
          encoder = "nvenc";
          hevc_mode = 3;
        };
      };

      systemd.user.services.sunshine = {
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        after = ["graphical-session.target"];
      };

      hardware.uinput.enable = true;

      users.users.${config.username}.extraGroups = [
        "uinput"
      ];
    };
  };
}
