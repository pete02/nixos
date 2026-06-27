{
  self,
  inputs,
  lib,
  ...
}:

{

  options = {
    flake.hyprlandBaseConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
    flake.hyprpanelConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
    hyprlandWithHyprpanel = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config =
    let
      hyprlandBaseConfig = ''
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

      hyprpanelConfig = {
        bar = {
          clock.format = "%a %b %d  %H:%M";
          launcher.autoDetectIcon = true;
          workspaces.show_icons = true;

          layouts = {
            "*" = {
              left = [
                "dashboard"
                "workspaces"
              ];
              middle = [ "media" ];
              right = [
                "volume"
                "netstat"
                "clock"
                "systray"
                "notifications"
                "network"
                "bluetooth"
              ];
            };
          };
        };
        menus = {
          clock = {
            time = {
              hideSeconds = true;
              military = true;
            };
            weather.unit = "metric";
          };
          dashboard.directories.enabled = false;
        };
        theme = {
          bar.transparent = true;
          font = {
            name = "CaskaydiaCove NF";
            size = "12px";
          };
        };
      };

      wrappersModule = { confFile, ... }: {
        args = [
          "--config"
          "${confFile}"
        ];
      };

      mkHyprlandPkg =
        {
          pkgs,
          extraConfig ? "",
          withHyprpanel ? true,
        }:
        let
          hyprpanelPkg =
            let
              storeConfig = pkgs.writeText "config.json" (builtins.toJSON hyprpanelConfig);
            in
            pkgs.writeShellScriptBin "hyprpanel" ''
              CONFIG_DIR="$XDG_RUNTIME_DIR/hyprpanel"
              mkdir -p "$CONFIG_DIR"

              cp ${storeConfig} "$CONFIG_DIR/config.json"
              chmod 644 "$CONFIG_DIR/config.json"

              export XDG_CONFIG_HOME="$XDG_RUNTIME_DIR"
              exec ${pkgs.hyprpanel}/bin/hyprpanel "$@"
            '';

          confFile = pkgs.writeText "hyprland.conf" (
            hyprlandBaseConfig # local, not self.hyprlandBaseConfig
            + extraConfig
            + lib.optionalString withHyprpanel ''
              exec-once = ${hyprpanelPkg}/bin/hyprpanel
            ''
          );

          rawPkg =
            (inputs.wrappers.wrapperModules.hyprland.apply {
              inherit pkgs;
              imports = [ wrappersModule ]; # local, not self.wrappersModules.hyprland
              _module.args = { inherit confFile; };
            }).wrapper;

        in
        pkgs.symlinkJoin {
          name = "hyprland-with-hyprpanel";
          paths = [ rawPkg ] ++ lib.optional withHyprpanel hyprpanelPkg;
          meta = rawPkg.meta // {
            outputsToInstall = builtins.filter (o: o != "man") (rawPkg.meta.outputsToInstall or [ "out" ]);
          };
          passthru = rawPkg.passthru // {
            inherit (rawPkg) override overrideAttrs;
            version = rawPkg.version;
          };
        };

    in
    {
      flake.packages.x86_64-linux.hyprland = mkHyprlandPkg {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        withHyprpanel = true;
      };

      flake.mkHyprlandPkg = mkHyprlandPkg;
    };
}
