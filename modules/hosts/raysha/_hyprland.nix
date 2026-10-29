{...}: {
  desktop.hyprland = {
    enable = true;
    extraConfig = ''

      hl.config({
        misc = {
          force_default_wallpaper = 2,
        },
      })

      hl.monitor({
        output = "desc:Dell Inc. AW3425DW DD5H274",
        mode = "3440x1440@175",
        position = "0x0",
        scale = 1,
        bitdepth = 10,
      })

      -- AOC Q32G1WG4: right of Dell
      hl.monitor({
          output = "desc:AOC Q32G1WG4 0x00000669",
          mode = "2560x1440@120",
          position = "3440x0",
          scale = 1,
      })

      -- Philips TV: right of AOC
      hl.monitor({
          output = "HDMI-A-3",
          mode = "3840x2160@59.97",
          position = "20000x0",
          scale = 1,
      })

      -- Pin workspaces to their intended monitors
      hl.workspace_rule({
          workspace = "1",
          monitor = "desc:Dell Inc. AW3425DW DD5H274",
          default = true,
      })

      hl.workspace_rule({
          workspace = "2",
          monitor = "desc:AOC Q32G1WG4 0x00000669",
          default = true,
      })

      hl.workspace_rule({
          workspace = "10",
          monitor = "HDMI-A-1",
          default = true,
      })

      hl.bind("SUPER + LEFT",  hl.dsp.window.move({ workspace = 1 }))

      hl.bind("SUPER + RIGHT", hl.dsp.window.move({ workspace = 2 }))
      hl.bind("SUPER + C", hl.dsp.exec_cmd("hyprctl dispatch movecursor 1720 720"))

      hl.bind("SUPER + N",
        hl.dsp.exec_cmd("/home/pete/wallpapers/switch.sh"))

      hl.on("hyprland.start", function()
        hl.exec_cmd("hyprctl dispatch workspace 1")
      end)
    '';
  };
}
