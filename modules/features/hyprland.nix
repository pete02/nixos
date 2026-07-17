{ self, inputs, ... }:
{
  flake.nixosModules.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      hyprlandPkg = self.mkHyprlandPkg {
        inherit pkgs;
        extraConfig = config.hyprlandExtraConfig;
      };
    in
    {
      options = {
        username = lib.mkOption { type = lib.types.str; };
        hyprlandExtraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };

      config = {

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
          hyprlandPkg
        ];

        fonts.packages = with pkgs; [ nerd-fonts.arimo ];
        programs.firefox.enable = true;
        xdg.portal = {
          enable = true;
          config.common.default = "*";
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        };

        security.rtkit.enable = true;
        security.pam.services.swaylock = { };

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

        services.greetd = {
          enable = true;
          settings.default_session = {
            command = "${hyprlandPkg}/bin/start-hyprland --path ${hyprlandPkg}/bin/hyprland";
            user = "pete";
          };
        };
      };
    };
}
