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

    # "http://aria.lan:8080/main" -> "aria.lan" (netrc machine name has no scheme/port/path)
    urlHost = url:
      builtins.head (lib.splitString ":" (
        builtins.head (lib.splitString "/" (
          lib.removePrefix "https://" (lib.removePrefix "http://" url)
        ))
      ));
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

      cache = {
        client = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Use the Attic binary cache as a substituter on this host.";
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://cache.example:8080/main";
            description = "Substituter URL, including the cache name.";
          };
          publicKey = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Cache public key (from `attic cache info`). Public by design.";
          };
          pullTokenSecret = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "attic/pull-token";
            description = ''
              Name of a sops secret containing a pull-only Attic token. Leave null
              if the cache is public (LAN only).
            '';
          };
        };

        server = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Run the Attic server on this host.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
          apiEndpoint = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://cache.example:8080/";
            description = "URL clients use to reach this server.";
          };
          envSecret = lib.mkOption {
            type = lib.types.str;
            default = "attic/env";
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
        boot.binfmt.emulatedSystems = ["aarch64-linux"];
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
          connect-timeout = 3;
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
