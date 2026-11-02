# streaming-desktop.nix
#
# Spike: one headless sway desktop per container group, N virtual outputs,
# one Sunshine instance per output. Untested sketch; expect to iterate.
#
#   desktop "main"
#   ├─ podman-main-compositor   sway (headless) + pipewire + apps
#   ├─ podman-main-sunshine0    Sunshine -> HEADLESS-1 (port 47989)
#   └─ podman-main-sunshine1    Sunshine -> HEADLESS-2 (port 48089)
#
# Containers share: host network, a runtime dir (wayland + pulse + sway ipc
# sockets) and the host /nix/store + /run/opengl-driver, so the NVIDIA
# userspace always matches the node's kernel driver (1070 Ti vs 4080 safe).
#
# Prereqs on the host:
#   nixpkgs.config.allowUnfree = true;            # CUDA-enabled Sunshine
#   hardware.graphics.enable = true;
#   services.xserver.videoDrivers = [ "nvidia" ];
#   hardware.nvidia.modesetting.enable = true;    # needed for GBM (set below as default)
#   boot.kernelModules = [ "nvidia_uvm" ];        # Sunshine's NVENC path uses CUDA
#
# Usage:
#   gaming.streaming.enable = true;
#   gaming.streaming.desktops.main.outputs = [
#     { mode = "3440x1440@60"; port = 47989; }
#     { mode = "2560x1440@60"; port = 48089; }
#   ];

{self, ...}:{
  flake.nixosModules.desktop-streaming=
  { config, lib, pkgs, ... }:

  let
    inherit (lib) mkOption mkEnableOption mkIf types;
    cfg = config.gaming.streaming;

    sunshine = pkgs.sunshine.override { cudaSupport = true; };

    # Same Env is used in the image and passed to every container.
    gpuEnv = {
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      GBM_BACKENDS_PATH = "/run/opengl-driver/lib/gbm";
      WLR_RENDERER = "gles2";
      WLR_NO_HARDWARE_CURSORS = "1";
      XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/etc/X11/xkb";
      FONTCONFIG_FILE = "${pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; }}";
      PATH = lib.makeBinPath [
        pkgs.coreutils
        pkgs.sway
        pkgs.dbus
        pkgs.pipewire
        pkgs.pulseaudio
        pkgs.wireplumber
        pkgs.bashInteractive
      ];
    };

    image = pkgs.dockerTools.streamLayeredImage {
      name = "local/streaming-desktop";
      tag = "latest";
      contents = [
        pkgs.dockerTools.binSh
        pkgs.bashInteractive
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.procps
        pkgs.dbus
        pkgs.sway
        pkgs.xwayland
        pkgs.foot
        pkgs.pipewire
        pkgs.wireplumber
        pkgs.pulseaudio # pactl only
        sunshine
      ];
      extraCommands = "mkdir -m 1777 tmp";
      config.Env = lib.mapAttrsToList (k: v: "${k}=${v}") gpuEnv;
    };

    # ---- per-desktop pieces -------------------------------------------------

    parseMode = mode:
      let m = builtins.match "([0-9]+)x([0-9]+)@([0-9]+)" mode;
      in assert lib.assertMsg (m != null) "mode must look like 3440x1440@60: ${mode}";
      { w = lib.toInt (builtins.elemAt m 0); h = lib.toInt (builtins.elemAt m 1); r = builtins.elemAt m 2; };

    swayConfig = name: d:
      let
        parsed = map (o: parseMode o.mode) d.outputs;
        withPos = lib.imap0 (i: p: p // {
          x = lib.foldl' (a: q: a + q.w) 0 (lib.take i parsed);
          n = toString (i + 1);
        }) parsed;
        setup = pkgs.writeShellScript "sway-setup-${name}" ''
          # runs inside sway (SWAYSOCK/WAYLAND_DISPLAY inherited)
          for i in $(seq ${toString (builtins.length d.outputs - 1)}); do
            swaymsg create_output
          done
          sleep 1
          swaymsg -t get_outputs | grep -E '"name"|"width"|"height"' || true
          echo "$WAYLAND_DISPLAY" > "$XDG_RUNTIME_DIR/wayland-name"
          touch "$XDG_RUNTIME_DIR/ready"
        '';
      in pkgs.writeText "sway-${name}.conf" ''
        set $mod Mod4
        bindsym $mod+Return exec foot
        bindsym $mod+Shift+q kill
        bindsym $mod+Shift+e exit
        focus_follows_mouse yes
        default_border pixel 1

        ${lib.concatMapStringsSep "\n" (p: ''
          output HEADLESS-${p.n} mode --custom ${toString p.w}x${toString p.h}@${p.r}Hz pos ${toString p.x} 0
          workspace ${p.n} output HEADLESS-${p.n}
        '') withPos}

        exec ${setup}
        ${lib.concatMapStringsSep "\n" (a: "exec ${a}") d.apps}
      '';

    compositorScript = name: d: pkgs.writeShellScript "compositor-${name}" ''
      set -eu
      export XDG_RUNTIME_DIR=/run/desktop
      export HOME=/home/desktop
      mkdir -p "$HOME"
      chmod 700 "$XDG_RUNTIME_DIR"
      rm -rf "$XDG_RUNTIME_DIR"/ready "$XDG_RUNTIME_DIR"/wayland-* \
            "$XDG_RUNTIME_DIR"/sway-ipc.* "$XDG_RUNTIME_DIR"/pulse "$XDG_RUNTIME_DIR"/pipewire-*

      # audio: one virtual sink both Sunshine instances capture from
      pipewire &
      wireplumber &
      pipewire-pulse &
      for i in $(seq 50); do
        [ -S "$XDG_RUNTIME_DIR/pulse/native" ] && break
        sleep 0.2
      done
      pactl load-module module-null-sink sink_name=stream sink_properties=device.description=stream
      pactl set-default-sink stream

      # headless outputs + libinput (so uinput devices from Sunshine are seen)
      export WLR_BACKENDS=headless,libinput
      export LIBSEAT_BACKEND=builtin
      export XDG_SESSION_TYPE=wayland
      export XDG_CURRENT_DESKTOP=sway
      exec dbus-run-session -- sway --unsupported-gpu -c ${swayConfig name d}
    '';

    sunshineFiles = name: i: o:
      let
        st = "/state";
        conf = pkgs.writeText "sunshine-${name}-${toString i}.conf" ''
          sunshine_name = ${name}-${toString i}
          port = ${toString o.port}
          origin_web_ui_allowed = lan
          capture = wlr
          output_name = ${toString i}
          encoder = nvenc
          hevc_mode = 2
          av1_mode = 1
          audio_sink = stream
          file_apps = ${pkgs.writeText "apps.json" ''{"apps":[{"name":"Desktop"}]}''}
          file_state = ${st}/sunshine_state.json
          credentials_file = ${st}/sunshine_credentials.json
          pkey = ${st}/key.pem
          cert = ${st}/cert.pem
          log_path = ${st}/sunshine.log
        '';
      in pkgs.writeShellScript "sunshine-${name}-${toString i}" ''
        set -eu
        export XDG_RUNTIME_DIR=/run/desktop
        export HOME=/state
        while [ ! -e "$XDG_RUNTIME_DIR/ready" ]; do sleep 0.5; done
        export WAYLAND_DISPLAY="$(cat "$XDG_RUNTIME_DIR/wayland-name")"
        export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
        exec sunshine ${conf}
      '';

    baseOpts = [ "--privileged" "--network=host" "--ipc=host" ];

    baseVolumes = name: [
      "/nix/store:/nix/store:ro"
      "/run/opengl-driver:/run/opengl-driver:ro"
      "/run/streaming/${name}:/run/desktop"
      "/dev/input:/dev/input"
      "/run/udev:/run/udev:ro"
    ];

    containersFor = name: d:
      [
        (lib.nameValuePair "${name}-compositor" {
          imageStream = image;
          image = "local/streaming-desktop:latest";
          cmd = [ "${compositorScript name d}" ];
          environment = gpuEnv;
          extraOptions = baseOpts ++ [ "--hostname=${name}" ];
          volumes = baseVolumes name ++ [ "${cfg.stateDir}/${name}/home:/home/desktop" ];
        })
      ] ++ (lib.imap0 (i: o:
        lib.nameValuePair "${name}-sunshine${toString i}" {
          imageStream = image;
          image = "local/streaming-desktop:latest";
          cmd = [ "${sunshineFiles name i o}" ];
          environment = gpuEnv;
          dependsOn = [ "${name}-compositor" ];
          extraOptions = baseOpts;
          volumes = baseVolumes name ++ [ "${cfg.stateDir}/${name}/sunshine${toString i}:/state" ];
        }) d.outputs);

    allOutputs = lib.concatMap (d: d.outputs) (lib.attrValues cfg.desktops);
    tcpPorts = o: map (n: o.port + n) [ (-5) 0 1 21 ];
    udpPorts = o: map (n: o.port + n) [ 9 10 11 13 ];
  in
  {
    options.gaming.streaming = {
      enable = mkEnableOption "headless multi-output Sunshine desktops";

      stateDir = mkOption {
        type = types.path;
        default = "/var/lib/streaming";
        description = "Persistent home + per-Sunshine pairing state, per desktop.";
      };

      desktops = mkOption {
        default = { };
        description = "Desktops: one sway compositor each, one Sunshine per output.";
        type = types.attrsOf (types.submodule {
          options = {
            outputs = mkOption {
              description = "Virtual outputs; order = HEADLESS-1, HEADLESS-2, ... left to right.";
              type = types.listOf (types.submodule {
                options = {
                  mode = mkOption { type = types.str; example = "3440x1440@60"; };
                  port = mkOption {
                    type = types.port;
                    description = "Sunshine base port (default Sunshine is 47989). Keep stable, pairing is per instance.";
                  };
                };
              });
            };
            apps = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Commands to exec inside sway at start.";
            };
          };
        });
      };
    };

    config = mkIf cfg.enable {
      virtualisation.oci-containers.backend = "podman";
      virtualisation.oci-containers.containers =
        lib.listToAttrs (lib.concatLists (lib.mapAttrsToList containersFor cfg.desktops));

      hardware.nvidia.modesetting.enable = lib.mkDefault true;
      boot.kernelModules = [ "uinput" "nvidia_uvm" ];

      systemd.tmpfiles.rules = lib.concatLists (lib.mapAttrsToList (name: d:
        [
          "d /run/streaming/${name} 0700 root root -"
          "d ${cfg.stateDir}/${name}/home 0755 root root -"
        ] ++ (lib.imap0 (i: _: "d ${cfg.stateDir}/${name}/sunshine${toString i} 0700 root root -") d.outputs)
      ) cfg.desktops);

      networking.firewall.allowedTCPPorts = lib.concatMap tcpPorts allOutputs;
      networking.firewall.allowedUDPPorts = lib.concatMap udpPorts allOutputs;
    };
  };

}