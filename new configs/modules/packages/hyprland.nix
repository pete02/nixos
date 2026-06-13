{ self, inputs, lib, ... }:

{


  options.flake.hyprlandBaseConfig = lib.mkOption {
    type = lib.types.lines;
    default = "";
  };

  config= {
    flake.wrappersModules.hyprland = { confFile, ... }: {
      args = [ "--config" "${confFile}" ];  # confFile passed in from perSystem
    };

    flake.hyprlandBaseConfig= ''
      general {
        gaps_in = 5
        gaps_out = 5
        resize_on_border = false
        allow_tearing = false
        layout = dwindle
      }
      decoration {
        rounding = 10
        active_opacity = 1.0
        inactive_opacity = 1.0
        shadow {
          enabled = true
          range = 4
          render_power = 3
          color = rgba(1a1a1aee)
        }
        blur {
          enabled = true
          size = 3
          passes = 1
          vibrancy = 0.1696
        }
      }
      input {
        kb_layout = fi
      }
      xwayland {
        force_zero_scaling = true
      }
      ecosystem {
        no_update_news = true
        no_donation_nag = true
      }
      bind = SUPER, SPACE, exec, rofi -show drun -show-icons
      bind = SUPER, C, killactive
      bind = SUPER, M, exit
      bind = SUPER, V, togglefloating
      bind = SUPER, up, fullscreenstate, 1
      bind = SUPER, F, fullscreen
      bind = SUPER, mouse_down, workspace, e+1
      bind = SUPER, mouse_up, workspace, e-1
      bind = SUPER, p, exec, export SCREENSHOT=~/screenshots/"$(date '+%Y-%m-%d_%H-%M-%S').png" && grim -g "$(slurp)" - | magick - -shave 1x1 PNG:- > "$SCREENSHOT" && cat "$SCREENSHOT" | wl-copy
      bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
      bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      bindel = ,XF86AudioPlay, exec, playerctl play-pause
      bindel = ,XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
      bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
    '';
  };
}