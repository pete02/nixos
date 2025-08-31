{pkgs, lib, config, ...}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      exec-once = ''${pkgs.waybar}/bin/waybar'';
      monitor=[
        "eDP-1,preferred,auto,auto"
        "HDMI-A-1,preferred,auto,auto"
      ];

      general={
        gaps_in = "5";
        gaps_out = "20";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration={
        rounding = "10";
        rounding_power = "2";

        # Change transparency of focused and unfocused windows
        active_opacity = "1.0";
        inactive_opacity = "1.0";

        shadow = {
            enabled = true;
            range = "4";
            render_power = "3";
            color = "rgba(1a1a1aee)";
        };

        # https://wiki.hypr.land/Configuring/Variables/#blur
        blur = {
            enabled = true;
            size = "3";
            passes = "1";

            vibrancy = "0.1696";
        };
      };

      dwindle =  {
        pseudotile = true;
        preserve_split = true;
      };

      input = {
        kb_layout = "fi";
      };

      "$mod" = "$SUPER";

      bind = [
      "$mod, SPACE, exec, rofi -show drun -show-icons"
      "$mod, C, killactive"
      "$mod, M, exit"
      "$mod, V, killactive"
      "$mod, left, movefocus, l"
      "$mod, right, movefocus, r"
      "$mod, up, movefocus, u"
      "$mod, down, movefocus, d"
      "$mod, mouse_down, workspace, e+1"
      "$mod, mouse_up, workspace, e-1"
      ];
      bindel=[
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];
      windowrule = [
        "suppressevent maximize, class:.*"
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      ];

    };

    
  };
}