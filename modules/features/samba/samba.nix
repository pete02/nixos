{self, ...}: {
  flake.nixosModules.samba = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.samba;

    enabledServers = lib.filterAttrs (_: server: server.enable) cfg.servers;
    enabledClients = lib.filterAttrs (_: client: client.enable) cfg.clients;

    serverSecrets = lib.unique (
      lib.concatMap
      (server:
        lib.optional (server.credentialsSecret != null)
        server.credentialsSecret)
      (lib.attrValues enabledServers)
    );

    clientSecrets = lib.unique (
      map (client: client.credentialsSecret)
      (lib.attrValues enabledClients)
    );

    shares =
      lib.foldl'
      (result: server:
        result
        // (lib.mapAttrs
          (_: share:
            {
              path = share.path;
              browseable =
                if share.browseable
                then "yes"
                else "no";
              "read only" =
                if share.readOnly
                then "yes"
                else "no";
              "guest ok" =
                if share.guestOk
                then "yes"
                else "no";
              "create mask" = share.createMask;
              "directory mask" = share.directoryMask;
              "force user" = share.forceUser;
              "force group" = share.forceGroup;
            }
            // lib.optionalAttrs (share.rootPreexec != null) {
              "root preexec" = share.rootPreexec;
              "root preexec close" =
                if share.rootPreexecClose
                then "yes"
                else "no";
            })
          server.shares))
      {}
      (lib.attrValues enabledServers);

    credentialServices = lib.listToAttrs (
      lib.concatLists (
        lib.mapAttrsToList
        (name: server:
          lib.optional (server.credentialsSecret != null) {
            name = "samba-credentials-${name}";
            value = {
              description = "Configure Samba credentials for ${name}";
              wantedBy = ["multi-user.target"];
              after = ["samba-smbd.service"];

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };

              script = ''
                set -eu

                credentials="/run/secrets/${server.credentialsSecret}"
                username=$(sed -n 's/^username=//p' "$credentials")
                password=$(sed -n 's/^password=//p' "$credentials")

                if [ -z "$username" ] || [ -z "$password" ]; then
                  echo "Missing Samba credentials in $credentials" >&2
                  exit 1
                fi

                if ${pkgs.samba}/bin/pdbedit -L -u "$username" >/dev/null 2>&1; then
                  printf '%s\n%s\n' "$password" "$password" \
                    | ${pkgs.samba}/bin/smbpasswd -s "$username"
                else
                  printf '%s\n%s\n' "$password" "$password" \
                    | ${pkgs.samba}/bin/smbpasswd -a -s "$username"
                fi
              '';
            };
          })
        enabledServers
      )
    );

    shareNames =
      lib.concatMap
      (server: builtins.attrNames server.shares)
      (lib.attrValues enabledServers);

    enabledShares =
      lib.concatMap
      (server: lib.attrValues server.shares)
      (lib.attrValues enabledServers);

    shareDirRules =
      map
      (share: "d ${share.path} ${share.mode} ${share.forceUser} ${share.forceGroup} -")
      (lib.filter (share: share.createDirectory) enabledShares);

    sharePaths = lib.unique (map (share: share.path) enabledShares);
  in {
    options.samba = {
      servers = lib.mkOption {
        default = {};
        description = "Named Samba server definitions and their shares.";

        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "this Samba server definition";

            credentialsSecret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "samba/server";
              description = ''
                SOPS secret containing username= and password=.
                Set to null if this server definition does not manage credentials.
              '';
            };

            shares = lib.mkOption {
              default = {};
              description = "Shares exported by this definition.";

              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "Local directory exported by Samba.";
                  };

                  readOnly = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };

                  browseable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                  };

                  guestOk = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };

                  createMask = lib.mkOption {
                    type = lib.types.str;
                    default = "0644";
                  };

                  directoryMask = lib.mkOption {
                    type = lib.types.str;
                    default = "0755";
                  };

                  forceUser = lib.mkOption {
                    type = lib.types.str;
                    default = config.username;
                  };

                  forceGroup = lib.mkOption {
                    type = lib.types.str;
                    default = "users";
                  };

                  rootPreexec = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Optional Samba root pre-exec command.";
                  };

                  rootPreexecClose = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                  };

                  createDirectory = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Create the share directory and manage its ownership and mode.";
                  };

                  mode = lib.mkOption {
                    type = lib.types.str;
                    default = "0755";
                    description = "Mode of the share directory itself.";
                  };
                };
              });
            };
          };
        });
      };

      clients = lib.mkOption {
        default = {};
        description = "Named CIFS client mounts.";
        type = lib.types.attrsOf (lib.types.submodule ({name, ...}: let
          reg = self.lib.fleet.samba.shares.${name} or {};
          need = field: throw "samba.clients.${name}: no ${field}; add '${name}' to fleet.samba.shares or set it explicitly";
        in {
          options = {
            enable = lib.mkEnableOption "this CIFS mount";
            host = lib.mkOption {
              type = lib.types.str;
              default = reg.host or (need "host");
            };
            share = lib.mkOption {
              type = lib.types.str;
              default = name;
            };
            mountPoint = lib.mkOption {
              type = lib.types.str;
              default = reg.mountPoint or (need "mountPoint");
            };
            credentialsSecret = lib.mkOption {
              type = lib.types.str;
              default = reg.credentialsSecret or "samba/server";
            };
            uid = lib.mkOption {
              type = lib.types.int;
              default = 1000;
            };
            gid = lib.mkOption {
              type = lib.types.int;
              default = 1000;
            };
            version = lib.mkOption {
              type = lib.types.str;
              default = "3.0";
            };
            idleTimeout = lib.mkOption {
              type = lib.types.str;
              default = "60";
            };
            deviceTimeout = lib.mkOption {
              type = lib.types.str;
              default = "5s";
            };
            mountTimeout = lib.mkOption {
              type = lib.types.str;
              default = "5s";
            };
          };
        }));
      };
    };

    config = lib.mkMerge [
      (lib.mkIf (enabledServers != {}) {
        assertions = [
          {
            assertion =
              builtins.length shareNames
              == builtins.length (lib.unique shareNames);
            message = "Samba share names must be unique across enabled server definitions.";
          }
        ];
      })

      (lib.mkIf (enabledServers != {}) {
        sops.secrets = lib.genAttrs serverSecrets (_: {});

        systemd.tmpfiles.rules = shareDirRules;

        services.samba = {
          enable = true;
          openFirewall = true;

          settings =
            {
              global = {
                security = "user";
                workgroup = "WORKGROUP";
                "server string" = "smbnix";
                "netbios name" = "smbnix";
                "hosts allow" = "192.168.88.0/24 10.0.0.0/24 127.0.0.1 localhost";
                "hosts deny" = "0.0.0.0/0";
                "guest account" = "nobody";
                "map to guest" = "bad user";
              };
            }
            // shares;
        };

        systemd.services =
          credentialServices
          // {
            # nixpkgs already sets RequiresMountsFor = "/var/lib/samba", so merge with it
            samba-smbd.unitConfig.RequiresMountsFor = lib.mkForce (
              lib.concatStringsSep " " (["/var/lib/samba"] ++ sharePaths)
            );
          };
      })

      (lib.mkIf (enabledClients != {}) {
        sops.secrets = lib.genAttrs clientSecrets (_: {});

        environment.systemPackages = [pkgs.cifs-utils];

        systemd.tmpfiles.rules =
          lib.mapAttrsToList
          (_: client: "d ${client.mountPoint} 0755 ${config.username} ${config.username} -")
          enabledClients;

        fileSystems =
          lib.mapAttrs'
          (_: client:
            lib.nameValuePair client.mountPoint {
              device = "//${client.host}/${client.share}";
              fsType = "cifs";

              options = [
                "x-systemd.automount"
                "noauto"
                "x-systemd.idle-timeout=${client.idleTimeout}"
                "x-systemd.device-timeout=${client.deviceTimeout}"
                "x-systemd.mount-timeout=${client.mountTimeout}"
                "credentials=/run/secrets/${client.credentialsSecret}"
                "vers=${client.version}"
                "uid=${toString client.uid}"
                "gid=${toString client.gid}"
              ];
            })
          enabledClients;
      })
    ];
  };
}
