{
  lib,
  config,
  pkgs,
  ...
}:

{
  options = {
    desktops.hyprland = lib.mkEnableOption "enables hyprland";
    desktops.hyprpanel = lib.mkEnableOption "enables hyprland";
  };

  config = lib.mkIf config.desktops.hyprland {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.systemPackages = with pkgs; [
      kitty
      mako
      xorg.xrandr
      grim
      slurp
      imagemagick
      wl-clipboard
      feh
      vlc
      playerctl
      rofi
      swaylock
    ];

    fonts.packages = with pkgs; [ nerd-fonts.arimo ];

    xdg.portal.enable = true;
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    security.rtkit.enable = true;
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
      settings = {
        default_session = {
          command = "${lib.getExe config.programs.hyprland.package}";
          user = "pete";
        };
      };
    };
  };
}
