{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    enable.hyprland = lib.mkEnableOption "enables hyprland";
    enable.hyprpanel = lib.mkEnableOption "enables hyprland";
  };
  config = lib.mkIf config.enable.hyprland {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };
    environment.systemPackages = with pkgs; [
      kitty
      dunst
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

    xdg.portal = {
      enable = true;
      gtk.enable = false; # disable GTK backend
      wlr.enable = true; # enable WLR backend
    };

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    services.upower.enable = true;

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
