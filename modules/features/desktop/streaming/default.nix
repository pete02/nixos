{self, ...}: {
  # SPIKE / SCAFFOLD: nothing in here has been built or run yet.
  #
  # Unverified assumptions (check these first when it misbehaves):
  #  1. Sunshine's `wlr` capture works against Hyprland. It needs the
  #     wlr-export-dmabuf protocol, which Hyprland may not expose any more.
  #     If capture fails, this is the first suspect (fallbacks: PipeWire
  #     capture, or a sway/Xorg-headless desktop instead).
  #  2. Input: AQ_BACKENDS=headless,libinput with LIBSEAT_BACKEND=noop lets
  #     the headless Hyprland see the uinput devices Sunshine creates.
  #  3. Headless output names / wl_output ordering. The entrypoint discovers
  #     them at runtime and passes the index to Sunshine as output_name.
  #  4. The image shares the host /nix/store and /run/opengl-driver, so the
  #     image must be built from the SAME nixpkgs as the host (glibc match
  #     with the NVIDIA userspace libraries).
  #  5. virtualisation.oci-containers `imageStream` needs a recent nixpkgs.
  #  6. Moonlight accepts "ip:port" when adding the 2nd+ output of a desktop.
  flake.nixosModules.desktop-streaming = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.gaming.streaming;
    inherit (lib) mkOption mkEnableOption types;

    toConf = lib.generators.toKeyValue {
      mkKeyValue = lib.generators.mkKeyValueDefault {} " = ";
    };

    stateRoot = "/var/lib/streaming";

    mkDesktop = name: d: let
      ip = (builtins.head d.outputs).ip;

      widths =
        map (o: lib.toInt (builtins.head (lib.splitString "x" o.mode))) d.outputs;
      xOffsets =
        lib.imap0 (i: _: lib.foldl' builtins.add 0 (lib.take i widths)) widths;

      hyprConf = pkgs.writeText "hyprland-${name}.conf" ''
        misc {
          disable_hyprland_logo = true
          disable_splash_rendering = true
        }
        cursor {
          no_hardware_cursors = true
        }
        ${lib.concatMapStringsSep "\n" (c: "exec-once = ${c}") d.hyprland.autostart}
        ${d.hyprland.extraConfig}
      '';

      # One block per output: create a headless monitor, place it, write a
      # Sunshine config for it, create its audio sink and start Sunshine.
      outputBlocks = lib.concatStrings (lib.imap0 (i: o: let
          n = toString (i + 1);
          port = 47989 + 100 * i;
          staticConf = pkgs.writeText "sunshine-${name}-${n}.conf" (toConf (d.sunshine.settings
            // {
              sunshine_name = "${name}-${n}";
              inherit port;
              csrf_allowed_origins = "https://${o.ip}:${toString (port + 1)}";
              file_state = "/state/sunshine-${n}/state.json";
              credentials_file = "/state/sunshine-${n}/credentials.json";
              pkey = "/state/sunshine-${n}/pkey.pem";
              cert = "/state/sunshine-${n}/cert.pem";
              audio_sink = "sunshine-${n}";
            }));
        in ''
          # ---- output ${n}: ${o.mode} on port ${toString port} ----
          before=$(hyprctl monitors all -j | jq -r '.[].name' | sort)
          hyprctl output create headless
          sleep 0.5
          name=$(comm -13 <(echo "$before") <(hyprctl monitors all -j | jq -r '.[].name' | sort) | head -n1)
          hyprctl keyword monitor "$name,${o.mode},${toString (builtins.elemAt xOffsets i)}x0,1"
          idx=$(hyprctl monitors all -j | jq -r --arg n "$name" 'map(.name) | index($n)')
          mkdir -p /state/sunshine-${n}
          { cat ${staticConf}; echo "output_name = $idx"; } > /state/sunshine-${n}.conf
          pactl load-module module-null-sink sink_name=sunshine-${n} >/dev/null
          sunshine /state/sunshine-${n}.conf &
        '')
      d.outputs);

      entrypoint = pkgs.writeShellApplication {
        name = "desktop-entrypoint";
        checkPhase = "";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          jq
          dbus
          hyprland
          pipewire
          wireplumber
          pulseaudio # pactl only
          d.sunshine.package
        ];
        text = ''
          # PipeWire wants a session bus
          if [ -z "$(printenv DBUS_SESSION_BUS_ADDRESS)" ]; then
            exec dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- "$0" "$@"
          fi

          export HOME=/home/user
          export XDG_RUNTIME_DIR=/tmp/xdg
          mkdir -p "$HOME" "$XDG_RUNTIME_DIR" /state
          chmod 700 "$XDG_RUNTIME_DIR"

          # host NVIDIA userspace (bind-mounted)
          export LD_LIBRARY_PATH=/run/opengl-driver/lib
          export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d
          export GBM_BACKENDS_PATH=/run/opengl-driver/lib/gbm
          export GBM_BACKEND=nvidia-drm

          export XDG_SESSION_TYPE=wayland
          export AQ_BACKENDS=headless,libinput
          export LIBSEAT_BACKEND=noop
          export WLR_NO_HARDWARE_CURSORS=1

          Hyprland --config ${hyprConf} --i-am-really-stupid &

          # wait for the compositor
          for _ in $(seq 1 150); do
            if [ -S "$XDG_RUNTIME_DIR/wayland-1" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then break; fi
            sleep 0.2
          done
          export WAYLAND_DISPLAY=wayland-1
          HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -n1)
          export HYPRLAND_INSTANCE_SIGNATURE

          # audio
          pipewire &
          wireplumber &
          pipewire-pulse &
          for _ in $(seq 1 100); do
            if pactl info >/dev/null 2>&1; then break; fi
            sleep 0.2
          done

          ${outputBlocks}

          pactl set-default-sink sunshine-1

          trap 'kill 0' EXIT
          # if anything dies, exit non-zero so the container restarts
          wait -n
          exit 1
        '';
      };

      image = pkgs.dockerTools.streamLayeredImage {
        name = "desktop-${name}";
        tag = "latest";
        contents =
          [
            pkgs.dockerTools.fakeNss
            pkgs.bashInteractive
            pkgs.coreutils
            entrypoint
          ]
          ++ d.apps;
        extraCommands = ''
          mkdir -p tmp home/user state
          chmod 1777 tmp
        '';
        config = {
          Entrypoint = ["${entrypoint}/bin/desktop-entrypoint"];
          Env = ["PATH=/bin"];
        };
      };
    in {
      image = "localhost/desktop-${name}:latest";
      imageStream = image;
      autoStart = true;

      devices =
        d.devices
        ++ [
          "/dev/dri:/dev/dri"
          "/dev/uinput:/dev/uinput"
        ];

      volumes =
        [
          "/nix/store:/nix/store:ro"
          "/run/opengl-driver:/run/opengl-driver:ro"
          # host input + udev db so libinput can see Sunshine's uinput devices
          "/dev/input:/dev/input"
          "/run/udev:/run/udev:ro"
          # Sunshine certs / pairing state: ALWAYS persistent, even when home is not
          "${stateRoot}/${name}/state:/state"
        ]
        ++ lib.optional d.persistentHome "${stateRoot}/${name}/home:/home/user";

      extraOptions =
        [
          "--network=streaming:ip=${ip}"
          "--device-cgroup-rule=c 13:* rmw"
          "--tmpfs=/tmp"
          "--shm-size=1g"
        ]
        ++ lib.optional (!d.persistentHome) "--tmpfs=/home/user";
    };

    outputType = types.submodule {
      options = {
        mode = mkOption {
          type = types.strMatching "[0-9]+x[0-9]+@[0-9]+(\\.[0-9]+)?";
          example = "3440x1440@60";
          description = "Virtual monitor mode, WIDTHxHEIGHT@REFRESH.";
        };
        ip = mkOption {
          type = types.str;
          example = "192.168.88.2";
          description = ''
            LAN address of the desktop container. All outputs of one desktop
            must use the same address; each output gets its own Sunshine
            port base (47989, 48089, ...).
          '';
        };
      };
    };

    desktopType = types.submodule {
      options = {
        compositor = mkOption {
          type = types.enum ["hyprland"];
          default = "hyprland";
        };
        outputs = mkOption {
          type = types.listOf outputType;
          description = "Virtual monitors; one Sunshine instance each.";
        };
        persistentHome = mkOption {
          type = types.bool;
          default = false;
          description = "Keep /home/user across restarts (otherwise tmpfs).";
        };
        apps = mkOption {
          type = types.listOf types.package;
          default = [pkgs.kitty];
        };
        devices = mkOption {
          type = types.listOf types.str;
          default = [
            "/dev/nvidia0"
            "/dev/nvidiactl"
            "/dev/nvidia-uvm"
            "/dev/nvidia-uvm-tools"
            "/dev/nvidia-modeset"
          ];
          description = "GPU device nodes passed to the container.";
        };
        hyprland = {
          autostart = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Commands for exec-once.";
          };
          extraConfig = mkOption {
            type = types.lines;
            default = ''
              bind = SUPER, Return, exec, kitty
              bind = SUPER, Q, killactive
              bind = SUPER SHIFT, E, exit
            '';
          };
        };
        sunshine = {
          package = mkOption {
            type = types.package;
            default = pkgs.sunshine;
          };
          settings = mkOption {
            type = types.attrsOf (types.oneOf [types.str types.int types.bool]);
            default = {
              capture = "wlr";
              encoder = "nvenc";
              hevc_mode = 3;
              origin_web_ui_allowed = "lan";
            };
            description = ''
              Extra sunshine.conf keys. Per-output identity (name, port, state
              files, output_name, audio_sink, csrf origin) is set by the module
              and cannot be overridden here.
            '';
          };
        };
      };
    };
  in {
    options.gaming.streaming = {
      enable = mkEnableOption "containerised multi-output Sunshine desktops";

      parentInterface = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "eno1";
        description = "NIC used as the macvlan parent for desktop containers.";
      };

      network = {
        subnet = mkOption {
          type = types.str;
          default = "192.168.88.0/24";
        };
        gateway = mkOption {
          type = types.str;
          default = "192.168.88.1";
        };
      };

      desktops = mkOption {
        type = types.attrsOf desktopType;
        default = {};
      };
    };

    config = lib.mkIf cfg.enable {
      assertions =
        [
          {
            assertion = cfg.parentInterface != null;
            message = "gaming.streaming.parentInterface must be set (macvlan parent).";
          }
        ]
        ++ lib.flatten (lib.mapAttrsToList (n: d: [
            {
              assertion = d.outputs != [];
              message = "gaming.streaming.desktops.${n}: at least one output is required.";
            }
            {
              assertion = lib.all (o: o.ip == (builtins.head d.outputs).ip) d.outputs;
              message = "gaming.streaming.desktops.${n}: all outputs must share one ip.";
            }
          ])
          cfg.desktops);

      hardware.graphics.enable = lib.mkDefault true;
      hardware.uinput.enable = true;
      boot.kernelModules = ["nvidia_uvm"];

      virtualisation.podman.enable = true;
      virtualisation.oci-containers.backend = lib.mkDefault "podman";
      virtualisation.oci-containers.containers =
        lib.mapAttrs' (n: d: lib.nameValuePair "desktop-${n}" (mkDesktop n d)) cfg.desktops;

      systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (n: d:
        [
          "d ${stateRoot}/${n} 0700 root root -"
          "d ${stateRoot}/${n}/state 0700 root root -"
        ]
        ++ lib.optional d.persistentHome "d ${stateRoot}/${n}/home 0700 root root -")
      cfg.desktops);

      systemd.services =
        {
          streaming-network = {
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            wants = ["network-online.target"];
            path = [pkgs.podman];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              podman network exists streaming || \
                podman network create -d macvlan \
                  --subnet ${cfg.network.subnet} \
                  --gateway ${cfg.network.gateway} \
                  -o parent=${cfg.parentInterface} \
                  streaming
            '';
          };
        }
        // lib.mapAttrs' (n: _:
          lib.nameValuePair "podman-desktop-${n}" {
            after = ["streaming-network.service"];
            requires = ["streaming-network.service"];
          })
        cfg.desktops;
    };
  };
}
