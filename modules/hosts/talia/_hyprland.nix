{...}: {
  shells.hyprland = {
    enable = true;
    extraConfig = ''
      hl.config({
        monitor = {
          "desc:Lenovo Group Limited 0x9052,1920x1080,0x0,1",
          "desc:Dell Inc. AW3425DW DD5H274,3440x1440@175,1920x0,1,bitdepth,10",
        },

        misc = {
          force_default_wallpaper = 2,
        },
      })

      hl.bind("SUPER + RIGHT",
        hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 1"))

      hl.bind("SUPER + LEFT",
        hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 2"))
    '';
    extraWayleConfig = ''
      [[bar.layout]]
      monitor = "*"
      right = [
        "volume",
        "netstat",
        "clock",
        "systray",
        "notifications",
        "network",
        "bluetooth",
        "battery",
      ]
    '';
  };
}
