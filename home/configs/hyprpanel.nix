{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  baseConfig = {
    bar = {
      clock = {
        format = "%a %b %d  %H:%M";
      };
      launcher = {
        autoDetectIcon = true;
      };
      workspaces = {
        show_icons = true;
      };
    };
    layout = {
      bar = {
        layouts = {
          "*" = {
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
    menus = {
      clock = {
        time = {
          hideSeconds = true;
          military = true;
        };
        weather = {
          unit = "metric";
        };
      };
      dashboard = {
        directories = {
          enabled = false;
        };
      };
    };
    theme = {
      bar = {
        transparent = true;
      };
      font = {
        name = "CaskaydiaCove NF";
        size = "12px";
      };
    };
  };

  mergedConfig = lib.recursiveUpdate baseConfig (config.programs.hyprpanel.extraSettings or { });
in
{
  programs.hyprpanel = lib.mkIf osConfig.hyprpanel.enable {
    enable = true;
    xdg.configFile."hyprpanel/config.json".text = builtins.toJSON mergedConfig;
  };
}
