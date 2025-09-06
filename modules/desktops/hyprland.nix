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
      xwayland.enable = true;
      package = inputs.hyprland.packages."${pkgs.system}".hyprland;
    };
    environment.systemPackages = with pkgs; [
      kitty
      #waybar
      #(waybar.overrideAttrs (oldAttrs: {
      #  mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
      #}))
      dunst
      libnotify

      swww
      rofi-wayland
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

    systemd.user.services.hyprland = {
      description = "Start huprland session Compositor";
      after = [ "graphical.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig.ExecStart = "${pkgs.hyprland}/bin/Hyprland";
      serviceConfig.Restart = "on-failure";
      serviceConfig.Environment = "XDG_RUNTIME_DIR=/run/user/${toString config.users.users.pete.uid}";
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd=echo 'login complete'";
          user = "pete";
        };
      };
    };
  };

}
