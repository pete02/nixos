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
      gtkgreet
      swww
      rofi-wayland
      cage
      gtkgreet
      regreet
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
      createHome = true;
      description = "Greeter user for greetd/gtkgreet";
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${lib.getExe config.programs.hyprland.package}";
          user = "pete";
        };
        initial_session = {
          command = "${pkgs.cage}/bin/cage -s -- ${pkgs.gtkgreet}/bin/gtkgreet";
          user = "greeter";
        };
      };
    };

    environment.etc."greetd/environments".text = ''
      dbus-run-session -- ${lib.getExe config.programs.hyprland.package}
    '';

    environment.etc."pamd/greetd".text = ''
      auth       required   pam_unix.so
      account    required   pam_unix.so
      session    required   pam_unix.so
      password   required   pam_unix.so
    '';
  };

}
