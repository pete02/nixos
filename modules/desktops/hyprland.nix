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
      hyprpanel
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

    users.users.greeter = {
      isSystemUser = true;
      description = "Greeter user for greetd";
      home = "/var/lib/greetd";
    };

    systemd.services."hyprland-greeter" = {
      description = "Hyprland for greetd";
      after = [ "systemd-user-sessions.service" "seatd.service" ];
      wants = [ "seatd.service" ];
      serviceConfig = {
        ExecStart = "${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/Hyprland";
        User = "greeter";   # we’ll make a dedicated user
        PAMName = "login";
        Environment = "XDG_SESSION_TYPE=wayland";
        Restart = "always";
      };
      wantedBy = [ "graphical.target" ];
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
          user = "greeter";
        };
      };
    };
  };

}
