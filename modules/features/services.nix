{ self, inputs, ... }: {
  flake.nixosModules.services =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      options.services = {
        cleaner = lib.mkEnableOption "Enable the cleaner service";
        gitops = lib.mkEnableOption "Enable the gitops service";
        autoUpdate = lib.mkEnableOption "Enables weekly automatic Nixos update and rebuild";
        gpucooler = lib.mkEnableOption "Enable the GPU cooler service";
        sshServer = lib.mkEnableOption "Enable the SSH service";
        sync = lib.mkEnableOption "Enable syncing to server";
        sambaClient = lib.mkEnableOption "enables router samba";
        mDNS = lib.mkEnableOption "Enable mDNS service for publishing IP to local network";
        sambaServer = lib.mkEnableOption "enables samba server";
        sambaTimelock = lib.mkEnableOption "enables timelock server";
      };

      config = lib.mkMerge [
        (lib.mkIf (config.services.cleaner) {
          systemd.services.cleaner = {
            description = "Clean Downloads and Trash at shutdown";
            wantedBy = [ "multi-user.target" ];
            before = [ "shutdown.target" ]; # run at shutdown
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.runtimeShell} -c 'rm -rf /home/pete/Downloads/* /home/pete/.local/share/Trash/*'";
            };
          };
        })

        (lib.mkIf (config.services.gitops) {
          systemd.services.gitops = {
            description = "Check remote NixOS config repo for updates";
            serviceConfig = {
              Type = "oneshot";
              Environment = "PATH=${pkgs.git}/bin:${pkgs.nixos-rebuild}/bin:/run/current-system/sw/bin";
              ExecStart = pkgs.writeShellScript "check-nixos-updates" (
                builtins.readFile "${self}/scripts/gitops.sh"
              );
            };
          };

          systemd.timers.gitops = {
            description = "Timer for auto-updating NixOS from git";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5m";
              OnUnitActiveSec = "1h";
              RandomizedDelaySec = "10m";
              Persistent = true;
            };
          };
        })

        (lib.mkIf (config.services.mDNS) {
          services.avahi = {
            enable = true;
            nssmdns4 = true;
            publish = {
              addresses = true;
              enable = true;
            };
          };
        })

        (lib.mkIf config.services.autoUpdate {
          systemd.services.nixos-auto-update = {
            description = "Update flake inputs and rebuild NixOS";

            serviceConfig = {
              Type = "oneshot";
              Environment = "PATH=${pkgs.git}/bin:${pkgs.nixos-rebuild}/bin:/run/current-system/sw/bin";
              ExecStart = pkgs.writeShellScript "nixos-auto-update" (
                builtins.readFile "${self}/scripts/update.sh"
              );
            };
          };

          systemd.timers.nixos-auto-update = {
            description = "Weekly automatic NixOS update";

            wantedBy = [ "timers.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            timerConfig = {
              OnBootSec = "15m";
              OnCalendar = "weekly";
              RandomizedDelaySec = "1h";
              Persistent = true;
            };
          };
        })

        (lib.mkIf (config.services.gpucooler) {
          systemd.services.gpu-fan-control = {
            description = "GPU Fan Control Service";
            wantedBy = [ "multi-user.target" ];
            after = [ "multi-user.target" ];

            serviceConfig = {
              ExecStart = pkgs.writeShellScript "gpu-fan-control" (
                builtins.readFile "${self}/scripts/gpu-cooler.sh"
              );
              Restart = "always";
              RestartSec = 1;
            };
          };
        })

        (lib.mkIf config.services.sshServer {
          services.openssh = {
            enable = true;
            ports = [ 22 ];
            settings = {
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              PermitRootLogin = "no";
              AllowUsers = [ config.username ];
              AuthorizedKeysFile = "/run/secrets/ssh/${config.hostname}/authorized_keys";
            };
          };
          sops.secrets."ssh/${config.hostname}/authorized_keys" = {
            owner = config.username;
          };

        })

        (lib.mkIf config.services.sync {
          environment.systemPackages = [ pkgs.rsync ];
          systemd.services.syncrestore = {
            description = "Restores desktop files.";
            after = [
              "network-online.target"
              "mnt-server.mount"
            ];
            wants = [
              "network-online.target"
              "mnt-server.mount"
            ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              User = config.username;
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "desktop-syncrestore" ''
                ${pkgs.rsync}/bin/rsync -au --info=progress2 /mnt/server/desktopsync/code /home/pete
              '';
            };
          };

          systemd.services.sync = {
            description = "sync desktop files.";
            wantedBy = [ "multi-user.target" ];
            before = [ "shutdown.target" ];

            serviceConfig = {
              User = config.username;
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "desktop-sync" (builtins.readFile "${self}/scripts/sync.sh");
            };
          };

        })

        (lib.mkIf config.services.sambaClient {
          systemd.tmpfiles.rules = [
            "d /mnt/router 0755 pete pete -"
          ];
          environment.systemPackages = [ pkgs.cifs-utils ];
          sops.secrets."samba/server" = { };

          fileSystems = {
            "/mnt/server" = {
              device = "//aria.local/server/";
              fsType = "cifs";
              options =
                let
                  # this line prevents hanging on network split
                  automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
                  creds = "credentials=/run/secrets/samba/server";
                  vers = "vers=3.0";
                  uidguid = "uid=1000,gid=1000";
                in
                [ "${automount_opts},${creds},${vers},${uidguid}" ];
            };
          };
        })

        (lib.mkIf config.services.sambaServer {
          sops.secrets."samba/server" = { };
          services.samba = {
            enable = true;
            openFirewall = true;
            settings = {
              global = {
                security = "user";
                "workgroup" = "WORKGROUP";
                "server string" = "smbnix";
                "netbios name" = "smbnix";
                "hosts allow" = "192.168.88.0/24 10.0.0.0/24 127.0.0.1 localhost";
                "hosts deny" = "0.0.0.0/0";
                "guest account" = "nobody";
                "map to guest" = "bad user";
              };
              "server" = {
                "path" = "/mnt/server";
                "browseable" = "yes";
                "read only" = "no";
                "guest ok" = "no";
                "create mask" = "0644";
                "directory mask" = "0755";
                "force user" = config.username;
                "force group" = "users";
              };
            };
          };

          systemd.services.samba-credentials = {
            description = "Set Samba password from sops secret";
            wantedBy = [ "multi-user.target" ];
            after = [
              "sops-nix.service"
              "samba.service"
            ];
            requires = [ "sops-nix.service" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };

            script = ''
              # Parse credentials file
              username=$(grep '^username=' /run/secrets/samba/server | cut -d= -f2)
              password=$(grep '^password=' /run/secrets/samba/server | cut -d= -f2)

              # Set samba password
              echo -e "$password\n$password" | ${pkgs.samba}/bin/smbpasswd -a -s "$username"
            '';
          };
        })

        (lib.mkIf config.services.sambaTimelock (
          let
            shareName   = "timelock";
            sharePath   = "/mnt/timelock";              # <-- adjust
            stateDir    = "/var/lib/samba-timelock";
            sessionFile = "${stateDir}/session-start";
            revokedFile = "${stateDir}/last-revoked";

            maxSessionSecs = 60 * 60;        # 1h
            cooldownSecs   = 72 * 60 * 60;   # 72h
            cutoffHour     = 21;             # 24h clock, local time

            preexec = pkgs.writeShellScript "samba-timelock-preexec" ''
              set -euo pipefail
              now=$(date +%s)
              hour=$(date +%-H)   # %-H, not %H: avoids "08"/"09" being read as octal

              if [ -f ${revokedFile} ]; then
                last=$(cat ${revokedFile})
                elapsed=$(( now - last ))
                if [ "$elapsed" -lt ${toString cooldownSecs} ]; then
                  logger -t samba-timelock "DENY connect: cooldown active ($(( (${toString cooldownSecs} - elapsed) / 3600 ))h left)"
                  exit 1
                fi
              fi

              if [ "$hour" -ge ${toString cutoffHour} ]; then
                logger -t samba-timelock "DENY connect: past cutoff (${toString cutoffHour}:00)"
                exit 1
              fi

              if [ ! -f ${sessionFile} ]; then
                echo "$now" > ${sessionFile}
                logger -t samba-timelock "ACCESS GRANTED: session started"
              fi
              exit 0
            '';

            postexec = pkgs.writeShellScript "samba-timelock-postexec" ''
              set -euo pipefail
              # Only finalize once every connection to the share is actually gone
              remaining=$(${pkgs.samba}/bin/smbstatus -S 2>/dev/null | awk -v s=${shareName} '$1==s' | wc -l)
              if [ "$remaining" -eq 0 ]; then
                date +%s > ${revokedFile}
                rm -f ${sessionFile}
                logger -t samba-timelock "ACCESS ENDED: 72h cooldown started"
              fi
            '';

            enforce = pkgs.writeShellScript "samba-timelock-enforce" ''
              set -euo pipefail
              [ -f ${sessionFile} ] || exit 0
              start=$(cat ${sessionFile})
              now=$(date +%s)
              hour=$(date +%-H)
              elapsed=$(( now - start ))

              if [ "$elapsed" -ge ${toString maxSessionSecs} ] || [ "$hour" -ge ${toString cutoffHour} ]; then
                logger -t samba-timelock "LIMIT REACHED: force-closing share"
                ${pkgs.samba}/bin/smbcontrol smbd close-share ${shareName} || true
                date +%s > ${revokedFile}
                rm -f ${sessionFile}
              fi
            '';
          in
          {
            sops.secrets."samba/timelock" = { };

            systemd.tmpfiles.rules = [
              "d ${stateDir} 0750 root root -"
            ];

            services.samba = {
              enable = true;
              openFirewall = true;
              settings = {
                global = {
                  security = "user";
                  "workgroup" = "WORKGROUP";
                };
                "${shareName}" = {
                  path = sharePath;
                  browseable = "yes";
                  "read only" = "no";
                  "guest ok" = "no";
                  "create mask" = "0644";
                  "directory mask" = "0755";
                  "force user" = config.username;
                  "force group" = "users";

                  "root preexec" = "${preexec}";
                  "root preexec close" = "yes";   # non-zero exit from preexec => connection is closed
                  "root postexec" = "${postexec}";
                };
              };
            };

            systemd.services.samba-timelock-credentials = {
              description = "Set Samba password for timelock share from sops secret";
              wantedBy = [ "multi-user.target" ];
              after = [ "sops-nix.service" "samba.service" ];
              requires = [ "sops-nix.service" ];
              serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
              script = ''
                username=$(grep '^username=' /run/secrets/samba/timelock | cut -d= -f2)
                password=$(grep '^password=' /run/secrets/samba/timelock | cut -d= -f2)
                echo -e "$password\n$password" | ${pkgs.samba}/bin/smbpasswd -a -s "$username"
              '';
            };

            systemd.services.samba-timelock-enforce = {
              description = "Enforce samba timelock session limits";
              serviceConfig.Type = "oneshot";
              script = "${enforce}";
            };

            systemd.timers.samba-timelock-enforce = {
              description = "Periodic check for samba timelock enforcement";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "1m";
                OnUnitActiveSec = "30s";
                AccuracySec = "5s";
              };
            };
          }
        ))

      ];
    };
}
