{...}: {
  flake.nixosModules.desktop-services = {
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
    options.desktop = {
      enable = lib.mkEnableOption "Enables desktop";
      services = {
        cleaner = lib.mkEnableOption "Enable the cleaner service";
        sync = lib.mkEnableOption "Enable syncing to server";
      };
    };
    config = lib.mkMerge [
      (lib.mkIf config.desktop.enable {
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
          rofi
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
      (lib.mkIf (config.desktop.services.cleaner) {
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
      (lib.mkIf config.desktop.services.sync {
        environment.systemPackages = [pkgs.rsync];
        systemd.services.syncrestore = {
          description = "Restores desktop files.";
          after = [
            "network-online.target"
            "mnt-server.mount"
          ];
          wants = [
            "network-online.target"
            "mnt-server.mount"
          ];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            User = config.username;
            Type = "oneshot";
            ExecStart = ''
              ${pkgs.rsync}/bin/rsync -au --info=progress2 /mnt/server/desktopsync/code /home/ ${config.username}
            '';
          };
        };

        systemd.services.sync = {
          description = "sync desktop files.";
          wantedBy = ["multi-user.target"];
          before = ["shutdown.target"];

          serviceConfig = {
            User = config.username;
            Type = "oneshot";
            ExecStart = "${sync}/bin/sync";
          };
        };
      })
    ];
  };
}
