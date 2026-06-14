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
      confFile = pkgs.writeText "hyprland.conf" (self.hyprlandBaseConfig + config.hyprlandExtraConfig);

      hyprlandPkg =
        (inputs.wrappers.wrapperModules.hyprland.apply {
          inherit pkgs;
          imports = [ self.wrappersModules.hyprland ];
          _module.args = { inherit confFile; };
        }).wrapper;
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

        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          package = hyprlandPkg;
        };

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
        ];

        fonts.packages = with pkgs; [ nerd-fonts.arimo ];
        programs.firefox.enable = true;
        xdg.portal = {
          enable = true;
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
            command = "start-hyprland";
            user = "pete";
          };
        };
      };
    };
}
