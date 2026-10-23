{...}: {
  desktop.hyprland = {
    enable = true;
    extraConfig = ''

      hl.config({
        misc = {
          force_default_wallpaper = 2,
        },
      })

      -- Philips TV
      hl.monitor({
          output = "HDMI-A-1",
          mode = "3840x2160@59.97",
          position = "0x0",
          scale = 1,
      })

      hl.workspace_rule({
          workspace = "1",
          monitor = "HDMI-A-1",
          default = true,
      })

    '';
  };
}
