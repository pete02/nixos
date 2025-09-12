{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  options = {
    hyprland.enable = lib.mkEnableOption "enables hyprland";
    hyprpanel.enable = lib.mkEnableOption "enables hyprland";
  };
  config = lib.mkIf config.hyprland.enable {

    programs.hyprland = {
      enable = true;
    };
    environment.systemPackages = with pkgs; [
      kitty
      #waybar
      #(waybar.overrideAttrs (oldAttrs: {
      #  mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
      #}))
      dunst
      libnotify
      gtkgreet
      swww
      rofi-wayland
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
