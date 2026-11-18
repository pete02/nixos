{...}: {
  flake.nixosModules.shells-services = {
    pkgs,
    self,
    lib,
    config,
    ...
  }: let
    sync = self.lib.mkScript pkgs {
      name = "sync";
      src = ./sync.sh;

      runtimeInputs = with pkgs; [
        rsync
      ];
      substitutions = {
        HOME = config.users.users.${config.username}.home;
        ENDPOINT = "/mnt/server/desktopsync";
      };
    };
  in {
    options.shells = {
      enable = lib.mkEnableOption "Enables desktop";
      services = {
        cleaner = lib.mkEnableOption "Enable the cleaner service";
      };
    };
    config = lib.mkMerge [
      (lib.mkIf config.shells.enable {
        environment.systemPackages = with pkgs; [
          kitty
          mako
          xrandr
          grim
          slurp
          imagemagick
          wl-clipboard
          feh
          vlc
          brave
          playerctl
          awww
          brightnessctl
          swaylock
          libinput
          kdePackages.dolphin
          kdePackages.kcalc
          gimp
        ];

        fonts.packages = with pkgs; [
          nerd-fonts.arimo
        ];

        programs.firefox.enable = true;

        xdg.portal = {
          enable = true;
          config.common.default = "*";
          extraPortals = [pkgs.xdg-desktop-portal-gtk];
        };

        security.rtkit.enable = true;
        security.pam.services.swaylock = {};

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
        };

        services.upower.enable = true;

        environment.sessionVariables = {
          GDK_BACKEND = "wayland,x11";
          QT_QPA_PLATFORM = "wayland;xcb";
          CLUTTER_BACKEND = "wayland";
          XDG_CURRENT_DESKTOP = "Hyprland";
          XDG_SESSION_TYPE = "wayland";
          XDG_SESSION_DESKTOP = "Hyprland";
          WLR_NO_HARDWARE_CURSORS = "1";
          CHROME_PASSWORD_STORE = "basic";
          NIXOS_OZONE_WL = "0";
        };
      })
      (lib.mkIf (config.shells.services.cleaner) {
        systemd.services.cleaner = {
          description = "Clean Downloads and Trash at shutdown";
          wantedBy = ["multi-user.target"];
          before = ["shutdown.target"]; # run at shutdown
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.runtimeShell} -c 'rm -rf /home/${config.username}/Downloads/* /home/${config.username}/.local/share/Trash/*'";
          };
        };
      })
    ];
  };
}
