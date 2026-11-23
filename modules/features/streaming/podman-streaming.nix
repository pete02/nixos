{
  self,
  inputs,
  ...
}: {
  # Podman layer only: runs NixOS systems as containers.
  #
  # Layering:  host (bare metal OR podman container)
  #              -> desktop selection   (desktop.desktop, desktops module)
  #                -> shell selection   (shells.*, configured by the desktop)
  #
  # A container is a NixOS system built from the same modules as a real host
  # (self.lib.featureModules). This module knows nothing about Hyprland,
  # audio, Sunshine or users: it only builds the image, wires devices, mounts,
  # network and persistence, and forwards input hotplug events.
  #
  # Secrets: containers run without extra capabilities, so sops-nix cannot
  # mount its ramfs inside them. Instead the HOST decrypts every secret the
  # guest declares in `sops.secrets`, copies it (with the owner/group/mode the
  # guest asked for) into /run/streaming-secrets/<name> on each container
  # start, and bind-mounts that directory read-only at /run/secrets. The guest
  # never sees an age key.
  #
  # Example:
  #
  #   streaming.podman = {
  #     enable = true;
  #     parentInterface = "enp4s0";
  #     containers.aria = {
  #       ip = "192.168.88.2";
  #       persistentHome = true;
  #       homePath = "/mnt/server/desktops/aria";   # optional
  #       config = {
  #         system.stateVersion = "26.05";
  #         username = "pete";
  #         desktop.desktop = "raysha";
  #         desktop.monitors = [{ output = "desk-1"; mode = "3440x1440@175"; }];
  #       };
  #     };
  #   };
  #
  # Needs `flake.lib.featureModules = featureModules;` in the hosts file.
  #
  # Still unverified:
  #  1. Running a NixOS `toplevel/init` under `podman --systemd=always` with
  #     the host store bind-mounted (may need extra capabilities/cgroup setup).
  #  2. The image shares the host /nix/store and the host GL userspace:
  #     containers are built from the SAME nixpkgs as the host.
  #  3. Input via the udev relay + /dev/input shared into every container
  #     (each container sees the others' Sunshine input devices).
  #
  # The flake module name is kept so the existing `streaming` aggregate still
  # loads it.
  flake.nixosModules.streaming-desktops = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.streaming.podman;
    inherit (lib) mkOption mkEnableOption types;

    stateRoot = "/var/lib/streaming";
    system = pkgs.stdenv.hostPlatform.system;

    # Container (and podman) name for a given key.
    cname = n: "streaming-${n}";

    # Host GL userspace is mounted here instead of /run/opengl-driver, so it
    # never collides with the container's own graphics setup.
    hostGl = "/run/host-opengl-driver";

    # Everything podman-specific about the *inside* of the container.
    guestModule = name: c: {config, ...}: let
      env = {
        LD_LIBRARY_PATH = "${hostGl}/lib";
        __EGL_VENDOR_LIBRARY_DIRS = "${hostGl}/share/glvnd/egl_vendor.d";
        __EGL_VENDOR_LIBRARY_FILENAMES = "${hostGl}/share/glvnd/egl_vendor.d/10_nvidia.json";
        __EGL_EXTERNAL_PLATFORM_CONFIG_DIRS = "${hostGl}/share/egl/egl_external_platform.d";
        GBM_BACKENDS_PATH = "${hostGl}/lib/gbm";
        GBM_BACKEND = "nvidia-drm";
        AQ_DRM_DEVICES = c.drmCard;
      };
    in {
      boot.isContainer = true;
      hostname = name;
      streaming.sunshine={
        address = lib.mkDefault c.ip;
        enable = true;
      };
      # Host NVIDIA userspace for system services and for the user manager.
      systemd.globalEnvironment = env;
      systemd.user.settings.Manager = {
        DefaultEnvironment = lib.mapAttrsToList (k: v: "${k}=${v}") env;
      };
      # Group ids must match the host so the passed-through device nodes
      # (video, input, uinput) are accessible.
      users.groups = lib.mapAttrs (_: gid: {inherit gid;}) c.hostGroupIds;
      users.users.${config.username} = {
        extraGroups = lib.attrNames c.hostGroupIds;
        uid = lib.mkDefault 1000;
      };
      # Pin the desktop user's uid. The host copies secrets in with numeric
      # ids, so they must be known at eval time (an auto-allocated uid is not).
      # 1000 is what the first normal user already gets, so existing /home
      # and /var/lib state keep matching.
      systemd.oomd.enable = false;
      services.dbus.implementation = "dbus";
      services.nscd.enable = false;
      system.nssModules = lib.mkForce [];

      environment.etc = {
        "hosts".enable = lib.mkForce false;
        "hostname".enable = lib.mkForce false;
      };

      # Secrets are decrypted by the host and mounted read-only at
      # /run/secrets. sops-nix must not try to mount a ramfs or decrypt
      # anything in here, so its activation snippets are disabled.
      # The key file path is a placeholder that only satisfies sops-nix's
      # "some key source must be configured" assertion; it is never read.
      sops.age.keyFile = lib.mkDefault "/run/sops-nix/key.txt";
      system.activationScripts.specialfs = lib.mkForce "";
      system.activationScripts.setupSecrets = lib.mkForce "";
      system.activationScripts.setupSecretsForUsers = lib.mkForce "";

      nix.enable = false;
      nix.gc.automatic = lib.mkForce false;
      nix.optimise.automatic = lib.mkForce false;
      nix.settings.auto-optimise-store = lib.mkForce false;
    };

    # The container IS a NixOS system: same modules and options as a host.
    mkSystem = name: c:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self system;
          selfPkgs = self.packages.${system};
        };
        modules = c.modules ++ [(guestModule name c) c.config];
      };

    # Evaluate every guest once; the host reads its sops.secrets and the
    # toplevel from here.
    guests = lib.mapAttrs mkSystem cfg.containers;

    # Host-side directory holding a container's decrypted secrets.
    secretsDir = n: "/run/streaming-secrets/${n}";

    # Name of the host sops secret backing guest secret `sn` of container `n`.
    hostSecretName = n: sn: "streaming/${n}/${sn}";

    # Copy the host-decrypted secrets into the per-container directory with
    # the owner/group/mode the guest declared. Podman runs rootful without a
    # user namespace, so numeric ids on the host are the ids in the container.
    copySecrets = n: let
      g = guests.${n}.config;
      uid = u: let
        v =
          if u == "root"
          then 0
          else g.users.users.${u}.uid;
      in
        if v == null
        then throw "streaming.podman.containers.${n}: user '${u}' owns a secret but has no fixed uid"
        else v;
      gid = grp: let
        v =
          if grp == "root"
          then 0
          else g.users.groups.${grp}.gid;
      in
        if v == null
        then throw "streaming.podman.containers.${n}: group '${grp}' owns a secret but has no fixed gid"
        else v;
      # Newer sops-nix leaves owner/group null and uses numeric uid/gid
      # (default 0) instead; older versions always set owner/group by name.
      ownerId = s:
        if (s.owner or null) != null
        then uid s.owner
        else (s.uid or 0);
      groupId = s:
        if (s.group or null) != null
        then gid s.group
        else (s.gid or 0);
    in ''
      rm -rf ${secretsDir n}
      install -d -m 0755 ${secretsDir n}
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (sn: s: ''
          install -D -m ${s.mode} -o ${toString (ownerId s)} -g ${toString (groupId s)} \
            ${lib.escapeShellArg config.sops.secrets.${hostSecretName n sn}.path} \
            ${lib.escapeShellArg "${secretsDir n}/${sn}"}
        '')
        g.sops.secrets)}
    '';

    mkContainer = name: c: let
      top = guests.${name}.config.system.build.toplevel;

      image = pkgs.dockerTools.streamLayeredImage {
        name = cname name;
        tag = "latest";
        config.Entrypoint = ["${top}/init"];
      };
    in {
      image = "localhost/${cname name}:latest";
      imageStream = image;
      autoStart = true;

      devices =
        c.devices
        ++ [
          "${c.drmCard}:${c.drmCard}"
          "${c.renderNode}:${c.renderNode}"
          "/dev/uinput:/dev/uinput"
        ];

      volumes =
        [
          "/nix/store:/nix/store:ro,nosuid,nodev"
          "/run/opengl-driver:${hostGl}:ro"
          "/dev/input:/dev/input"
          "/run/udev:/run/udev:ro"
          "${stateRoot}/${name}/var-lib:/var/lib"
          # Host-decrypted secrets (see copySecrets), read-only.
          "${secretsDir name}:/run/secrets:ro"
        ]
        ++ lib.optional c.persistentHome "${c.homePath}:/home"
        ++ c.extraVolumes;

      extraOptions = [
        "--network=streaming:ip=${c.ip}"
        "--systemd=always"
        "--device-cgroup-rule=c 13:* rmw"
        "--shm-size=1g"
        # Keep tmpfs only for runtime paths, NOT /etc
        "--tmpfs=/run"
        "--tmpfs=/run/wrappers:rw,exec,suid,mode=755"
        "--tmpfs=/tmp"
      ];
    };

    # Containers on their own (macvlan) network namespace never receive udev
    # hotplug events, because the kernel and udevd only broadcast into the init
    # netns. This relay listens to the host's libudev broadcasts (netlink group 2)
    # and re-sends input/hidraw events into each container's netns, so libinput
    # inside sees uinput devices as they appear.
    relayTargets = map cname (lib.attrNames cfg.containers);

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

    containerType = types.submodule ({name, ...}: {
      options = {
        ip = mkOption {
          type = types.str;
          example = "192.168.88.2";
          description = "macvlan LAN address of the container.";
        };

        modules = mkOption {
          type = types.listOf types.deferredModule;
          default = self.lib.featureModules;
          defaultText = lib.literalExpression "self.lib.featureModules";
          description = "NixOS modules the container system is built from (same as a host).";
        };

        config = mkOption {
          type = types.deferredModule;
          default = {};
          description = ''
            NixOS configuration of the container, written like a host config:
            `desktop.desktop`, `desktop.monitors`, `username`, ...
          '';
        };

        persistentHome = mkOption {
          type = types.bool;
          default = false;
          description = "Persist /home across restarts (otherwise it lives in the container).";
        };

        homePath = mkOption {
          type = types.str;
          default = "${stateRoot}/${name}/home";
          defaultText = lib.literalExpression ''"/var/lib/streaming/<name>/home"'';
          example = "/mnt/server/desktops/aria";
          description = "Host path mounted at /home when persistentHome is true.";
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

        hostGroupIds = mkOption {
          type = types.attrsOf types.int;
          default = {
            video = 26;
            input = 174;
            uinput = 992;
          };
          description = ''
            Host group ids the container user joins, so GPU and input device
            nodes are accessible. Must match the host (`getent group video`).
          '';
        };

        extraVolumes = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["/mnt/server/games:/games"];
          description = "Extra bind mounts.";
        };
      };
    });
  in {
    options.streaming.podman = {
      enable = mkEnableOption "NixOS desktops running as podman containers";

      parentInterface = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "enp4s0";
        description = "NIC used as the macvlan parent for the containers.";
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

      containers = mkOption {
        type = types.attrsOf containerType;
        default = {};
        description = "Containers to run; each is a NixOS system.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions =
        [
          {
            assertion = cfg.parentInterface != null;
            message = "streaming.podman.parentInterface must be set (macvlan parent).";
          }
          {
            assertion = let
              ips = map (c: c.ip) (lib.attrValues cfg.containers);
            in
              lib.unique ips == ips;
            message = "streaming.podman.containers must use distinct ip addresses.";
          }
        ]
        ++ lib.mapAttrsToList (n: c: {
          assertion = lib.hasPrefix "/" c.homePath;
          message = "streaming.podman.containers.${n}: homePath must be absolute.";
        })
        cfg.containers
        ++ lib.flatten (lib.mapAttrsToList (n: _: let
            g = guests.${n}.config.sops;
          in [
            {
              assertion = g.templates == {};
              message = "streaming.podman.containers.${n}: sops.templates are not supported in containers (host-decrypted secrets only).";
            }
            {
              assertion = lib.all (s: !s.neededForUsers) (lib.attrValues g.secrets);
              message = "streaming.podman.containers.${n}: neededForUsers secrets are not supported in containers.";
            }
          ])
          cfg.containers);

      # The host decrypts exactly the secrets each guest declares (root-only
      # on the host); copySecrets hands them to the container.
      sops.secrets = lib.mkMerge (lib.mapAttrsToList (n: _:
        lib.mapAttrs' (sn: s:
          lib.nameValuePair (hostSecretName n sn) {
            inherit (s) sopsFile key format;
          })
        guests.${n}.config.sops.secrets)
      cfg.containers);

      hardware.uinput.enable = true;
      boot.kernelModules = ["nvidia_uvm"];

      virtualisation.podman.enable = true;
      virtualisation.oci-containers.backend = lib.mkDefault "podman";
      virtualisation.oci-containers.containers =
        lib.mapAttrs' (n: c: lib.nameValuePair (cname n) (mkContainer n c)) cfg.containers;

      systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (n: c:
        [
          "d ${stateRoot}/${n} 0755 root root -"
          "d ${stateRoot}/${n}/var-lib 0755 root root -"
        ]
        ++ lib.optional c.persistentHome "d ${c.homePath} 0755 root root -")
      cfg.containers);

      systemd.services =
        {
          streaming-udev-relay = lib.mkIf (relayTargets != []) {
            description = "Relay host udev input events into streaming containers";
            wantedBy = ["multi-user.target"];
            after = ["podman.socket"];
            path = [pkgs.podman];
            serviceConfig = {
              ExecStart = "${pkgs.python3}/bin/python3 ${relayScript} ${lib.concatStringsSep " " relayTargets}";
              Restart = "always";
              RestartSec = 2;
            };
          };

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
          lib.nameValuePair "podman-${cname n}" {
            after = ["streaming-network.service"];
            requires = ["streaming-network.service"];
            # Runs on every (re)start, so rotated secrets are picked up.
            preStart = copySecrets n;
          })
        cfg.containers;
    };
  };
}
