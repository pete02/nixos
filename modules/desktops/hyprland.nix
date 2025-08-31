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
  };
  config = lib.mkIf config.hyprland.enable {

    programs.hyprland.enable = true;
    programs.hyprland.xwayland = true;
    programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;
    environment.systemPackages = with pkgs; [
      kitty
      #waybar
      #(waybar.overrideAttrs (oldAttrs: {
      #  mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
      #}))
      dunst
      libnotify
      hyprpanel
      swww
      rofi-wayland
    ];

    fonts.packages = with pkgs;[ nerd-fonts.arimo ];

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
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
          user = "pete";
        };
      }
      ;
    };
  };

}
