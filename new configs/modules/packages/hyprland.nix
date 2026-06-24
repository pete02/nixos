{
  self,
  inputs,
  lib,
  ...
}:

{

  options= {
    flake.hyprlandBaseConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
    flake.hyprpanelConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
    };
    hyprlandWithHyprpanel = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = {
    flake.mkHyprlandPkg =
      {
        pkgs,
        extraConfig ? "",
        withHyprpanel ? true,
      }:
      let
        confFile = pkgs.writeText "hyprland.conf" (
          self.hyprlandBaseConfig
          + extraConfig
          + lib.optionalString withHyprpanel ''
            exec-once = hyprpanel
          ''
        );

        rawPkg = (inputs.wrappers.wrapperModules.hyprland.apply {
          inherit pkgs;
          imports = [ self.wrappersModules.hyprland ];
          _module.args = { inherit confFile; };
        }).wrapper;

        hyprpanelPkg =
          if !withHyprpanel then null
          else
            let
              configDir = pkgs.writeTextDir "hyprpanel/config.json"
                (builtins.toJSON self.hyprpanelConfig);

              wrapped = pkgs.makeWrapper pkgs.hyprpanel
                "${pkgs.stdenv.mkDerivation {
                  name = "hyprpanel-wrapped";
                  nativeBuildInputs = [ pkgs.makeWrapper ];
                  buildCommand = ''
                    mkdir -p $out/bin
                    makeWrapper ${pkgs.hyprpanel}/bin/hyprpanel $out/bin/hyprpanel \
                      --set XDG_CONFIG_HOME ${configDir}
                  '';
                }}/bin/hyprpanel";
            in
              pkgs.stdenv.mkDerivation {
                name = "hyprpanel-wrapped";
                nativeBuildInputs = [ pkgs.makeWrapper ];
                buildCommand = ''
                  mkdir -p $out/bin
                  makeWrapper ${pkgs.hyprpanel}/bin/hyprpanel $out/bin/hyprpanel \
                    --set XDG_CONFIG_HOME ${configDir}
                '';
              };
      in
      pkgs.symlinkJoin {
        name = "hyprland-with-hyprpanel";
        paths = [ rawPkg ] ++ lib.optional withHyprpanel hyprpanelPkg;
        meta = rawPkg.meta;
        passthru = {
          inherit (rawPkg) override overrideAttrs;
          version = rawPkg.version;
        };
      };

    flake.wrappersModules.hyprland = { confFile, ... }: {
      args = [ "--config" "${confFile}" ];
    };


    flake.hyprlandBaseConfig = ''
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
    flake.hyprpanelConfig = {
      bar = {
        clock = {
          format = "%a %b %d  %H:%M";
        };
        launcher = {
          autoDetectIcon = true;
        };
        layouts = {
          "*" = {
            left = [ "dashboard" "workspaces" ];
            middle = [ "media" ];
            right = [ "volume" "netstat" "clock" "systray" "notifications" "network" "bluetooth" ];
          };
        };
        workspaces = {
          show_icons = true;
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

  };
}
