{self, ...}: {
  flake.nixosModules.nixbuilder = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.nixbuilder;
    client = cfg.cache.client;
    server = cfg.cache.server;

    urlHost = url:
      builtins.head (lib.splitString ":" (
        builtins.head (lib.splitString "/" (
          lib.removePrefix "https://" (lib.removePrefix "http://" url)
        ))
      ));

    signingHosts = builtins.attrNames (
      lib.filterAttrs (_: h: h.signing or h.buildServer or false) self.lib.hosts
    );
    signingKeys = self.lib.fleet.signingKeys;
    privSecret = h: "nix/signing/${h}";
    signsHere = lib.hasAttr (config.hostname or "") signingKeys;
  in {
    options.nixbuilder = {
      usesBuilders = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      buildServer = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      signing.enable = lib.mkOption {
        type = lib.types.bool;
        default = signsHere;
        description = "Sign store paths built on this host with this host's key from sops.";
      };
      cache = {
        client = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Use the Attic binary cache as a substituter on this host.";
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = self.lib.fleet.cache.url;
            description = "Substituter URL, including the cache name.";
          };
          publicKey = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = self.lib.fleet.cache.publicKey;
            description = "Cache public key (from `attic cache info`). Public by design.";
          };
          pullTokenSecret = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = self.lib.fleet.cache.pullTokenSecret;
            example = "attic/pull-token";
            description = ''
              Name of a sops secret containing a pull-only Attic token. Leave null
              if the cache is public (LAN only).
            '';
          };
          cachePush = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enables pushing the build artifacts to Attic";
          };
        };

        server = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default =
              (config.hostname or null) == self.lib.fleet.cache.host;
            description = "Run the Attic server on this host.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
          apiEndpoint = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = self.lib.fleet.cache.apiEndpoint;
            example = "http://cache.example:8080/";
            description = "URL clients use to reach this server.";
          };
          envSecret = lib.mkOption {
            type = lib.types.str;
            default = self.lib.fleet.cache.envSecret;
            description = ''
              sops secret containing the server environment file
              (ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=...).
            '';
          };
          retention = lib.mkOption {
            type = lib.types.str;
            default = "3 months";
          };
          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open the port on all interfaces. Prefer restricting to LAN/docker subnets.";
          };
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf (cfg.usesBuilders or false) {
        nix.distributedBuilds = true;
        nix.settings.builders-use-substitutes = true;
        nix.buildMachines =
          builtins.map (hostname: {
            hostName = hostname;
            systems = ["x86_64-linux" "aarch64-linux"];
            protocol = "ssh-ng";
            maxJobs = 8;
            speedFactor = 1;
            supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
            mandatoryFeatures = [];
            # deliberately no sshUser / sshKey here; ssh resolves those
            # from the "Host ${hostname}" alias already in /etc/ssh/ssh_config
          })
          (builtins.attrNames (lib.filterAttrs (_: host: host.buildServer or false) self.lib.hosts));
      })

      (lib.mkIf (cfg.buildServer or false) {
        boot.binfmt = {
          emulatedSystems = ["aarch64-linux" "i686-linux"];
          preferStaticEmulators = true;
          registrations.aarch64-linux.wrapInterpreterInShell = lib.mkForce false;
        };
      })

      (lib.mkIf cfg.signing.enable {
        assertions = [
          {
            assertion = signsHere;
            message = "nixbuilder.signing.enable is set but this host has no entry in fleet.signingKeys.";
          }
        ];

        sops.secrets.${privSecret config.hostname} = {};

        nix.settings.secret-key-files = [
          config.sops.secrets.${privSecret config.hostname}.path
        ];
      })

      # client side: every host trusts the public key of each signing host
      (lib.mkIf (signingKeys != {}) {
        nix.settings.trusted-public-keys = lib.attrValues signingKeys;
      })

      # ---- Attic client (every host) ----
      (lib.mkIf client.enable {
        assertions = [
          {
            assertion = client.url != null && client.publicKey != null;
            message = "nixbuilder.cache.client: url and publicKey must be set.";
          }
        ];

        # These lists merge with the NixOS defaults, so cache.nixos.org stays.
        nix.settings = {
          substituters = [client.url];
          trusted-public-keys = [client.publicKey];
          # Never let an unreachable cache break builds or boots.
          connect-timeout = 5;
          stalled-download-timeout = 15;
          fallback = true;
        };
      })

      # Optional pull token, so the cache needn't be public even on the LAN.
      (lib.mkIf (client.enable && client.pullTokenSecret != null) {
        sops.secrets.${client.pullTokenSecret} = {};

        sops.templates."attic-netrc".content = ''
          machine ${urlHost client.url} login attic-token password ${config.sops.placeholder.${client.pullTokenSecret}}
        '';

        nix.settings.netrc-file = config.sops.templates."attic-netrc".path;

        sops.templates."attic-push-config".content = ''
          default-server = "aria"

          [servers.aria]
          endpoint = "${lib.removeSuffix "/main" client.url}"
          token-file = "${config.sops.secrets.${client.pullTokenSecret}.path}"
        '';

        nix.settings.post-build-hook = lib.mkIf client.cachePush (
          pkgs.writeShellScript
          "attic-post-build-hook" ''
            set -u
            set -f
            export IFS=' '

            if [ -z "''${OUT_PATHS:-}" ]; then
              exit 0
            fi

            config_dir="$(mktemp -d)"
            trap 'rm -rf "$config_dir"' EXIT

            mkdir -p "$config_dir/attic"
            cp ${config.sops.templates."attic-push-config".path} \
              "$config_dir/attic/config.toml"

            export XDG_CONFIG_HOME="$config_dir"

            ${pkgs.attic-client}/bin/attic push aria:main $OUT_PATHS \
              || echo "Warning: Attic upload failed; build outputs remain local." >&2

            exit 0
          ''
        );
      })

      # ---- Attic server (one host, e.g. aria) ----
      (lib.mkIf server.enable {
        assertions = [
          {
            assertion = server.apiEndpoint != null;
            message = "nixbuilder.cache.server.apiEndpoint must be set.";
          }
        ];

        # Root-owned 0400 is fine: systemd reads EnvironmentFile as root.
        sops.secrets.${server.envSecret} = {};

        services.atticd = {
          enable = true;
          environmentFile = config.sops.secrets.${server.envSecret}.path;
          settings = {
            listen = "[::]:${toString server.port}";
            api-endpoint = server.apiEndpoint;
            garbage-collection.default-retention-period = server.retention;
          };
        };

        networking.firewall.allowedTCPPorts =
          lib.mkIf server.openFirewall [server.port];
      })
    ];
  };
}
