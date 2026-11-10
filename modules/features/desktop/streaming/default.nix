{self, ...}: {
  # Containerised headless desktops streamed with one Sunshine instance per
  # virtual output. The desktop itself is NOT defined here: it comes from a
  # package (by default your `self.mkHyprlandPkg`, i.e. base.lua + extraConfig).
  #
  # Example:
  #
  #   gaming.streaming = {
  #     enable = true;
  #     parentInterface = "enp4s0";
  #     desktops.aria = {
  #       outputs = [{ mode = "3440x1440@60"; ip = "192.168.88.2"; }];
  #       persistentHome = false;
  #       desktop.extraConfig = '''-- Lua appended to base.lua''';   # uses self.mkHyprlandPkg
  #       # or bring your own package:
  #       # desktop.package = self.mkHyprlandPkg { inherit pkgs; extraConfig = "..."; };
  #       packages = with pkgs; [ kitty ];
  #       desktop.hostProfile = true;   # also expose /run/current-system/sw
  #     };
  #   };
  #
  # Still unverified:
  #  1. Launching `bin/hyprland` directly instead of via start-hyprland (Hyprland
  #     may print a warning about it).
  #  2. Input via AQ_BACKENDS=headless,libinput + LIBSEAT_BACKEND=noop.
  #  3. The image shares the host /nix/store + /run/opengl-driver: build from the
  #     SAME nixpkgs as the host.
  #  4. Moonlight accepts "ip:port" for the 2nd+ output of a desktop.
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

    anyMacvlan = lib.any (d: !d.hostNetwork) (lib.attrValues cfg.desktops);

    # Containers on their own (macvlan) network namespace never receive udev
    # hotplug events, because the kernel and udevd only broadcast into the init
    # netns. This relay listens to the host's libudev broadcasts (netlink group 2)
    # and re-sends input/hidraw events into each such container's netns, so
    # libinput in the compositor sees Sunshine's devices as they appear.
    relayTargets =
      lib.mapAttrsToList (n: _: "desktop-${n}")
      (lib.filterAttrs (_: d: !d.hostNetwork) cfg.desktops);

    relayScript = pkgs.writeText "streaming-udev-relay.py" ''
      import os, socket, struct, subprocess, sys

      NETLINK_KOBJECT_UEVENT = 15
      GROUP_UDEV = 2
      FORWARD = {b"input", b"hidraw"}
      targets = sys.argv[1:]


      def netns_path(name):
          r = subprocess.run(
              ["podman", "inspect", "-f", "{{.State.Pid}}", name],
              capture_output=True, text=True)
          pid = r.stdout.strip()
          if r.returncode != 0 or pid in ("", "0"):
              return None
          return "/proc/%s/ns/net" % pid


      def inject(path, data):
          child = os.fork()
          if child == 0:
              code = 1
              try:
                  fd = os.open(path, os.O_RDONLY)
                  os.setns(fd, os.CLONE_NEWNET)
                  s = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW,
                                    NETLINK_KOBJECT_UEVENT)
                  s.bind((0, 0))
                  s.sendto(data, (0, GROUP_UDEV))
                  code = 0
              except Exception as e:
                  print("udev-relay: inject into %s failed: %r" % (path, e),
                        file=sys.stderr, flush=True)
              os._exit(code)
          os.waitpid(child, 0)


      rx = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, NETLINK_KOBJECT_UEVENT)
      rx.bind((0, GROUP_UDEV))
      print("udev-relay: forwarding input events to", targets, flush=True)

      while True:
          data = rx.recv(65536)
          if data[:8] != b"libudev\0" or len(data) < 40:
              continue
          off, length = struct.unpack_from("II", data, 16)
          props = data[off:off + length].split(b"\0")
          sub = [p[10:] for p in props if p.startswith(b"SUBSYSTEM=")]
          if not sub or sub[0] not in FORWARD:
              continue
          for t in targets:
              path = netns_path(t)
              if path:
                  inject(path, data)
    '';

    # With macvlan every desktop has its own IP, so ports restart at 47989 per
    # desktop. With hostNetwork all desktops share the host's ports, so the
    # port base is allocated across all host-network desktops (sorted by name).
    portShift = n: d:
      if d.hostNetwork
      then let
        hostNames = lib.filter (m: cfg.desktops.${m}.hostNetwork) (lib.attrNames cfg.desktops);
      in
        lib.foldl' (acc: m: acc + builtins.length cfg.desktops.${m}.outputs) 0
        (lib.filter (m: m < n) hostNames)
      else 0;

    mkDesktop = name: d: let
      ip = (builtins.head d.outputs).ip;

      # The compositor package: yours if given, otherwise built from base.lua
      # plus desktop.extraConfig via the flake's mkHyprlandPkg.
      desktopPkg =
        if d.desktop.package != null
        then d.desktop.package
        else
          self.mkHyprlandPkg {
            inherit pkgs;
            extraConfig = d.desktop.extraConfig;
          };

      widths =
        map (o: lib.toInt (builtins.head (lib.splitString "x" o.mode))) d.outputs;
      xOffsets =
        lib.imap0 (i: _: lib.foldl' builtins.add 0 (lib.take i widths)) widths;

      # One block per output: create a named headless monitor, set its mode and
      # position, write a Sunshine config for it, create its audio sink, start Sunshine.
      outputBlocks = lib.concatStrings (lib.imap0 (i: o: let
          n = toString (i + 1);
          port = 47989 + 100 * (i + portShift name d);
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
          name=desk-${n}
          hyprctl output create headless "$name"
          sleep 0.5
          hyprctl eval "hl.monitor({ output = \"$name\", mode = \"${o.mode}\", position = \"${toString (builtins.elemAt xOffsets i)}x0\", scale = 1 })"
          sleep 0.5
          idx=$(hyprctl -j monitors all | jq -r --arg n "$name" 'map(.name) | index($n)')
          mkdir -p /state/sunshine-${n}
          { cat ${staticConf}; echo "output_name = $idx"; } > /state/sunshine-${n}.conf
          pactl load-module module-null-sink sink_name=sunshine-${n} >/dev/null
          sunshine /state/sunshine-${n}.conf &
        '')
        d.outputs);

      entrypoint = pkgs.writeShellApplication {
        name = "desktop-entrypoint";
        checkPhase = "";
        runtimeInputs =
          [desktopPkg]
          ++ (with pkgs; [
            coreutils
            gnugrep
            jq
            dbus
            hyprland # hyprctl fallback if the desktop package does not ship it
            pipewire
            wireplumber
            pulseaudio # pactl only
            mesa-demos # eglinfo, diagnostics only
            d.sunshine.package
          ]);
        text = ''
          # PipeWire wants a session bus
          if [ -z "$(printenv DBUS_SESSION_BUS_ADDRESS)" ]; then
            exec dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- "$0" "$@"
          fi

          export HOME=/home/user
          export XDG_RUNTIME_DIR=/tmp/xdg
          mkdir -p "$HOME" "$XDG_RUNTIME_DIR" /state
          chmod 700 "$XDG_RUNTIME_DIR"

          # apps started by the desktop (exec_cmd, launchers) resolve from here
          export PATH="$PATH:/bin${lib.optionalString d.desktop.hostProfile ":/run/current-system/sw/bin"}"
          ${lib.optionalString d.desktop.hostProfile "export XDG_DATA_DIRS=/run/current-system/sw/share"}

          # host NVIDIA userspace (bind-mounted)
          export LD_LIBRARY_PATH=/run/opengl-driver/lib
          export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d
          export GBM_BACKENDS_PATH=/run/opengl-driver/lib/gbm
          export GBM_BACKEND=nvidia-drm
          # NVIDIA's EGL needs its GBM/Wayland external-platform configs to initialise
          export __EGL_EXTERNAL_PLATFORM_CONFIG_DIRS=/run/opengl-driver/share/egl/egl_external_platform.d
          # pin EGL to the NVIDIA vendor library for the compositor AND Sunshine
          if [ -e /run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json ]; then
            export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json
          fi

          export XDG_SESSION_TYPE=wayland
          export AQ_BACKENDS=headless,libinput
          export AQ_DRM_DEVICES=${d.drmCard}
          export LIBSEAT_BACKEND=noop

          # the desktop package carries its own config (--config baked in)
          ${d.desktop.command desktopPkg} &

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

          # diagnostics in the journal
          echo "== hyprland config errors =="; hyprctl configerrors || true
          echo "== monitors =="; hyprctl monitors all || true

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
          ++ d.packages;
        extraCommands = ''
          mkdir -p tmp home/user state
          chmod 1777 tmp
          # fakeNss only ships root + nobody; replace its passwd/group with
          # entries for the unprivileged user the container runs as, so PipeWire,
          # dbus and friends can resolve uid/gid (and HOME=/home/user matches).
          rm -f etc/passwd etc/group
          cat > etc/passwd <<EOF
          root:x:0:0:root user:/var/empty:/bin/sh
          user:x:${toString d.uid}:${toString d.gid}:Desktop user:/home/user:/bin/sh
          nobody:x:65534:65534:nobody:/var/empty:/bin/sh
          EOF
          cat > etc/group <<EOF
          root:x:0:
          user:x:${toString d.gid}:
          nobody:x:65534:
          ${lib.concatStrings (map (g: "g${toString g}:x:${toString g}:user\n") d.extraGids)}
          EOF
        '';
        config = {
          Entrypoint = ["${entrypoint}/bin/desktop-entrypoint"];
          Env = ["PATH=/bin"];
          # by NAME, not uid:gid - podman then resolves the primary gid AND
          # the supplementary groups from the image's /etc/passwd + /etc/group
          User = "user";
        };
      };
    in {
      image = "localhost/desktop-${name}:latest";
      imageStream = image;
      autoStart = true;
      environment = d.extraEnv;

      devices =
        d.devices
        ++ [
          "${d.drmCard}:${d.drmCard}"
          "${d.renderNode}:${d.renderNode}"
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
        ++ lib.optional d.persistentHome "${stateRoot}/${name}/home:/home/user"
        ++ lib.optionals d.desktop.hostProfile [
          "/run/current-system/sw:/run/current-system/sw:ro"
          "/etc/fonts:/etc/fonts:ro"
        ]
        ++ d.extraVolumes;

      extraOptions =
        [
          (
            if d.hostNetwork
            then "--network=host"
            else "--network=streaming:ip=${ip}"
          )
          "--device-cgroup-rule=c 13:* rmw"
          # podman's tmpfs is mode 1777 (world-writable), so the unprivileged
          # container user can create $XDG_RUNTIME_DIR (and $HOME) in it
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
        outputs = mkOption {
          type = types.listOf outputType;
          description = "Virtual monitors; one Sunshine instance each.";
        };
        persistentHome = mkOption {
          type = types.bool;
          default = false;
          description = "Keep /home/user across restarts (otherwise tmpfs).";
        };
        hostNetwork = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Run the container in the host network namespace instead of a macvlan
            IP. Fallback for keyboard/mouse: udev hotplug events (netlink) only
            reach the init network namespace, so a compositor in a separate
            netns never learns about Sunshine's uinput devices. Macvlan
            desktops get those events through the streaming-udev-relay
            service instead; use this only if the relay does not work. With this on,
            `ip` is just the host's LAN address (used for the CSRF origin),
            Sunshine's ports are opened in the host firewall, and every output
            of every host-network desktop gets its own port base (47989,
            48089, ... allocated across desktops in name order).
            NOTE: all desktops on the host then see all uinput devices, so
            keyboard/mouse input is shared between them.
          '';
        };

        desktop = {
          package = mkOption {
            type = types.nullOr types.package;
            default = null;
            description = ''
              Compositor package to run (e.g. `self.mkHyprlandPkg {...}` or
              `self.packages.x86_64-linux.hyprland`). When null, the module builds
              one with `self.mkHyprlandPkg { extraConfig = desktop.extraConfig; }`,
              i.e. your base.lua plus the extra Lua below.
            '';
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Lua appended to base.lua (only used when desktop.package is null).";
          };
          command = mkOption {
            type = types.functionTo types.str;
            default = pkg: "${pkg}/bin/hyprland";
            defaultText = lib.literalExpression ''pkg: "''${pkg}/bin/hyprland"'';
            description = ''
              Shell command that starts the compositor, given the package.
              The container runs as an unprivileged user (see desktop.uid), so
              Hyprland needs no `--i-am-really-stupid` flag; to go through
              the launcher use e.g.
              `pkg: "''${pkg}/bin/start-hyprland --path ''${pkg}/bin/hyprland"`
              (check how it forwards flags first).
            '';
          };
          hostProfile = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Expose the host's /run/current-system/sw (and /etc/fonts) read-only
              and put it on PATH, so the desktop sees whatever your other desktop
              modules install system-wide (bar, launcher, ...).
            '';
          };
        };

        packages = mkOption {
          type = types.listOf types.package;
          default = [];
          description = "Extra packages on PATH inside the container (/bin).";
        };
        extraVolumes = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["/etc/xdg:/etc/xdg:ro"];
          description = "Extra bind mounts, e.g. for config your desktop modules put in /etc.";
        };
        extraEnv = mkOption {
          type = types.attrsOf types.str;
          default = {};
          description = "Extra environment variables for the container.";
        };

        uid = mkOption {
          type = types.int;
          default = 1000;
          description = ''
            Numeric user id the container runs as. fakeNss only ships `root`
            and `nobody`, so the image injects its own passwd/group entry named
            `user` for this uid (home `/home/user`), matching the container's
            `HOME`. Any uid works, since the entry is generated from it.
          '';
        };
        gid = mkOption {
          type = types.int;
          default = 1000;
          description = ''
            Numeric group id the container runs as (primary group). The image
            gets a matching passwd/group entry (named `user`). For host-owned
            device groups (`/dev/dri/card1` is `video`, `/dev/uinput` is the
            `uinput` group) prefer listing them in `extraGids` instead, so the
            user keeps its own primary gid.
          '';
        };
        extraGids = mkOption {
          type = types.listOf types.int;
          default = [];
          example = [ 26 ];
          description = ''
            Supplementary group ids the container user also belongs to. The
            image's passwd/group entries are generated, so the container runs
            its user by NAME and podman resolves these groups from /etc/group.
            Required for GPU access: /dev/dri/card1 is `root:video` mode 0660,
            so the video group id (host `getent group video`) must be listed
            here, or Hyprland's DRM backend fails with `CBackend::create()
            failed!`. Add the host's `uinput` group id too for
            keyboard/mouse streaming through /dev/uinput.
          '';
        };

        drmCard = mkOption {
          type = types.str;
          default = "/dev/dri/card1";
          description = "DRM card node of the NVIDIA GPU (see /dev/dri/by-path).";
        };
        renderNode = mkOption {
          type = types.str;
          default = "/dev/dri/renderD128";
          description = "Render node of the NVIDIA GPU.";
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
          description = "NVIDIA device nodes passed to the container.";
        };

        sunshine = {
          package = mkOption {
            type = types.package;
            default = pkgs.sunshine.override {cudaSupport = true;};
          };
          settings = mkOption {
            type = types.attrsOf (types.oneOf [types.str types.int types.bool]);
            default = {
              capture = "wlr";
              encoder = "nvenc";
              hevc_mode = 0;
              origin_web_ui_allowed = "lan";
              system_tray = "disabled";
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
        example = "enp4s0";
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
            assertion = !anyMacvlan || cfg.parentInterface != null;
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

      networking.firewall = let
        hostNames = lib.filter (n: cfg.desktops.${n}.hostNetwork) (lib.attrNames cfg.desktops);
        bases = n: let
          d = cfg.desktops.${n};
        in
          lib.imap0 (i: _: 47989 + 100 * (i + portShift n d)) d.outputs;
      in {
        allowedTCPPorts =
          lib.concatMap (n: lib.concatMap (p: [(p - 5) p (p + 1) (p + 21)]) (bases n)) hostNames;
        allowedUDPPorts =
          lib.concatMap (n: lib.concatMap (p: lib.range (p + 9) (p + 13)) (bases n)) hostNames;
      };

      systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (n: d:
        [
          "d ${stateRoot}/${n} 0755 root root -"
          # owned by the container's uid so it can write Sunshine state there
          "d ${stateRoot}/${n}/state 0700 ${toString d.uid} ${toString d.gid} -"
        ]
        ++ lib.optional d.persistentHome
          "d ${stateRoot}/${n}/home 0700 ${toString d.uid} ${toString d.gid} -")
      cfg.desktops);

      systemd.services =
        {
          streaming-udev-relay = lib.mkIf (relayTargets != []) {
            description = "Relay host udev input events into desktop containers";
            wantedBy = ["multi-user.target"];
            after = ["podman.socket"];
            path = [pkgs.podman];
            serviceConfig = {
              ExecStart = "${pkgs.python3}/bin/python3 ${relayScript} ${lib.concatStringsSep " " relayTargets}";
              Restart = "always";
              RestartSec = 2;
            };
          };

          streaming-network = lib.mkIf anyMacvlan {
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
        // lib.mapAttrs' (n: d:
          lib.nameValuePair "podman-desktop-${n}" (lib.mkIf (!d.hostNetwork) {
            after = ["streaming-network.service"];
            requires = ["streaming-network.service"];
          }))
        cfg.desktops;
    };
  };
}
