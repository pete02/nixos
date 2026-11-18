{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatMapStringsSep optionalString;
  luaString = value:
    builtins.toJSON value;

  monitorConfig =
    concatMapStringsSep "\n"
    (entry: ''
      hl.monitor({
        output = ${luaString entry.monitor.output},
        mode = ${luaString entry.monitor.mode},
        position = ${luaString entry.monitor.position},
        scale = 1,
        ${optionalString (entry.monitor.bitdepth != null) ''
        bitdepth = ${toString entry.monitor.bitdepth},
      ''}
      })

      hl.workspace_rule({
        workspace = "${toString (entry.index + 1)}",
        monitor = ${luaString entry.monitor.output},
        default = true,
      })
    '')
    (lib.imap0 (index: monitor: {inherit index monitor;}) config.desktop.monitors);
in {
  config = lib.mkIf (config.desktop.desktop == "raysha") {
    shells.hyprland = {
      enable = true;
      extraConfig = ''
        hl.config({
          misc = {
            force_default_wallpaper = 2,
          },
        })
        ${monitorConfig}

        ${lib.optionalString (builtins.length config.desktop.monitors > 1) ''
          hl.bind("SUPER + LEFT", hl.dsp.window.move({ workspace = 1 }))
          hl.bind("SUPER + RIGHT", hl.dsp.window.move({ workspace = 2 }))
        ''}
        hl.bind("SUPER + C", hl.dsp.exec_cmd("hyprctl dispatch movecursor 1720 720"))
        hl.bind("SUPER + N", hl.dsp.exec_cmd("/home/pete/wallpapers/switch.sh"))

        hl.on("hyprland.start", function()
          hl.exec_cmd("hyprctl dispatch workspace 1")
        end)
      '';
    };

    common-tools.books = true;
    gaming = {
      steam = true;
      rpcs3 = true;
      performance = true;
      graphics = true;
      compatibility = true;
    };
    environment.systemPackages = with pkgs; [
      via
      moonlight-qt
      rofi
    ];

    dev = {
      enable = true;
      vscode = true;
      android = true;
      ld = true;
    };
  };
}
