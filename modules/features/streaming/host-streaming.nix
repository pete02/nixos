
{self, ...}: {
  # Sunshine streaming, in two modes:
  #
  #   host      one instance capturing the real display (kms), as before.
  #   headless  one instance per output of a headless compositor (wlr capture),
  #             each with its own port, state, audio sink and output index.
  #             Selected automatically inside containers (boot.isContainer).
  #
  # Headless instances run as systemd user services after the desktop session
  # (shells.hyprland's `hyprland-session` in headless mode).
  flake.nixosModules.streaming-sunshine = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.streaming.sunshine;
    headless = cfg.mode == "headless";

    toConf = lib.generators.toKeyValue {
      mkKeyValue = lib.generators.mkKeyValueDefault {} " = ";
    };

    stateRoot = "/var/lib/sunshine";
    user = config.users.users.${config.username};

    instances =
      lib.imap0 (i: output: {
        n = toString (i + 1);
        inherit output;
        port = cfg.basePort + 100 * i;
      })
      cfg.outputs;

    staticConf = i:
      pkgs.writeText "sunshine-${i.n}.conf" (toConf (cfg.settings
        // {
          sunshine_name = "${config.hostname}-${i.n}";
          inherit (i) port;
          file_state = "${stateRoot}/${i.n}/state.json";
          credentials_file = "${stateRoot}/${i.n}/credentials.json";
          pkey = "${stateRoot}/${i.n}/pkey.pem";
          cert = "${stateRoot}/${i.n}/cert.pem";
          audio_sink = "sunshine-${i.n}";
        }
        // lib.optionalAttrs (cfg.address != null) {
          csrf_allowed_origins = "https://${cfg.address}:${toString (i.port + 1)}";
        }));

    mkInstance = i:
      lib.nameValuePair "sunshine-${i.n}" {
        description = "Sunshine for output ${i.output}";
        wantedBy = ["default.target"];
        after = ["hyprland-session.service" "pipewire-pulse.service"];
        wants = ["pipewire-pulse.service"];

        # hyprctl, pactl and friends: the system profile plus jq/pactl.
        path = [config.system.path pkgs.jq pkgs.pulseaudio];

        environment.WAYLAND_DISPLAY = "wayland-1";

        serviceConfig = {
          Restart = "always";
          RestartSec = 2;
        };

        script = ''
          set -eu

          : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"

          # Wait for the compositor's Wayland socket.
          wayland_socket="$XDG_RUNTIME_DIR/wayland-1"

          for _ in $(seq 1 150); do
            if [ -S "$wayland_socket" ]; then
              break
            fi
            sleep 0.2
          done

          if [ ! -S "$wayland_socket" ]; then
            echo "Hyprland Wayland socket did not appear: $wayland_socket" >&2
            exit 1
          fi

          # Discover the running Hyprland instance.
          for _ in $(seq 1 150); do
            for instance in "$XDG_RUNTIME_DIR"/hypr/*; do
              if [ -d "$instance" ]; then
                export HYPRLAND_INSTANCE_SIGNATURE="''${instance##*/}"
                break 2
              fi
            done
            sleep 0.2
          done

          if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            echo "Hyprland instance not found in $XDG_RUNTIME_DIR/hypr" >&2
            exit 1
          fi

          # Wait for this output to exist.
          output_found=false

          for _ in $(seq 1 150); do
            if hyprctl -j monitors all |
              jq -e --arg n ${lib.escapeShellArg i.output} \
                'any(.[]; .name == $n)' >/dev/null; then
              output_found=true
              break
            fi
            sleep 0.2
          done

          if [ "$output_found" != true ]; then
            echo "Hyprland output not found: ${i.output}" >&2
            exit 1
          fi

          # Resolve the output index Sunshine expects.
          idx=$(${cfg.outputIndexCommand i.output})

          if [ -z "$idx" ] || [ "$idx" = null ]; then
            echo "Could not determine Sunshine output index for ${i.output}" >&2
            exit 1
          fi

          pactl load-module module-null-sink sink_name=sunshine-${i.n} >/dev/null || true
          ${lib.optionalString (i.n == "1") "pactl set-default-sink sunshine-1"}

          { cat ${staticConf i}; echo "output_name = $idx"; } > ${stateRoot}/${i.n}/sunshine.conf

          exec ${cfg.package}/bin/sunshine ${stateRoot}/${i.n}/sunshine.conf
        '';
      };
  in {
    options.streaming.sunshine = {
      enable = lib.mkEnableOption "Sunshine game streaming";

      mode = lib.mkOption {
        type = lib.types.enum ["host" "headless"];
        default =
          if config.boot.isContainer
          then "headless"
          else "host";
        description = "host: capture the real display. headless: one Sunshine instance per headless output.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.sunshine.override {cudaSupport = true;};
        description = "Sunshine package (used directly in headless mode).";
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf (lib.types.oneOf [lib.types.str lib.types.int lib.types.bool]);
        default =
          if headless
          then {
            capture = "wlr";
            encoder = "nvenc";
            hevc_mode = 0;
            origin_web_ui_allowed = "lan";
            system_tray = "disabled";
          }
          else {
            capture = "kms";
            encoder = "nvenc";
            hevc_mode = 3;
          };
        description = ''
          sunshine.conf keys. In headless mode the per-instance identity (name,
          port, state files, output_name, audio_sink, csrf origin) is set by
          the module and overrides these.
        '';
      };

      outputs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = map (m: m.output) config.desktop.monitors;
        defaultText = lib.literalExpression "map (m: m.output) config.desktop.monitors";
        description = "Headless outputs to stream, one Sunshine instance each.";
      };

      basePort = lib.mkOption {
        type = lib.types.port;
        default = 47989;
        description = "Port base of the first instance; each further output adds 100.";
      };

      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Address clients use to reach the web UI (csrf origin). Set by the podman layer for containers.";
      };

      outputIndexCommand = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        default = out: ''hyprctl -j monitors all | jq -r --arg n ${lib.escapeShellArg out} 'map(.name) | index($n)' '';
        defaultText = lib.literalExpression "Hyprland: index of the output in `hyprctl monitors all`";
        description = ''
          Shell snippet printing the capture index Sunshine's `output_name`
          expects for a given output name. Shell-specific: override it when a
          desktop does not use Hyprland.
        '';
      };
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
      {
        hardware.uinput.enable = true;
        users.users.${config.username}.extraGroups = ["uinput"];
      }

      (lib.mkIf (!headless) {
        services.sunshine = {
          enable = true;
          capSysAdmin = true;
          openFirewall = true;
          settings = cfg.settings;
        };

        systemd.user.services.sunshine = {
          wantedBy = ["graphical-session.target"];
          partOf = ["graphical-session.target"];
          after = ["graphical-session.target"];
        };
      })

      (lib.mkIf headless {
        environment.systemPackages = [cfg.package];

        systemd.user.services = lib.listToAttrs (map mkInstance instances);

        systemd.tmpfiles.rules =
          ["d ${stateRoot} 0755 root root -"]
          ++ map (i: "d ${stateRoot}/${i.n} 0700 ${config.username} ${user.group} -") instances;

        # The container sits directly on the LAN (macvlan). Open the Sunshine
        # ports, and default the firewall off: containers normally lack
        # CAP_NET_ADMIN, so iptables rules cannot be applied inside.
        networking.firewall = {
          enable = lib.mkDefault false;
          allowedTCPPorts = lib.concatMap (i: [(i.port - 5) i.port (i.port + 1) (i.port + 21)]) instances;
          allowedUDPPorts = lib.concatMap (i: lib.range (i.port + 9) (i.port + 13)) instances;
        };
      })
    ]);
  };
}
