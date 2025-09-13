{ lib, osConfig, ... }:
{
  programs.hyprpanel = lib.mkIf osConfig.hyprpanel.enable {
    enable = true;
    settings = {
      layout = {
        bar = {
          layouts = {
            "0" = {
              left = [
                "dashboard"
                "workspaces"
              ];
              middle = [ "media" ];
              right = [
                "volume"
                "systray"
                "notifications"
              ];
            };
          };
        };
      };

      bar.launcher.autoDetectIcon = true;
      bar.workspaces.show_icons = true;
      bar.clock.format = "%a %b %d  %H:%M";

      menus.clock = {
        time = {
          military = true;
          hideSeconds = true;
        };
        weather.unit = "metric";
      };

      menus.dashboard.directories.enabled = false;
      theme.bar.transparent = true;

      theme.font = {
        name = "CaskaydiaCove NF";
        size = "12px";
      };
    };
  };
}
