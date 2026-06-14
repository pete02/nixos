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
        gpucooler = lib.mkEnableOption "Enable the GPU cooler service";
        ssh = lib.mkEnableOption "Enable the SSH service";
        sync = lib.mkEnableOption "Enable syncing to server";
        samba-client = lib.mkEnableOption "enables router samba";
        ollama = lib.mkEnableOption "enable ollama service";
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

        (lib.mkIf config.services.enable.ssh {
          services.openssh = {
            enable = true;
            ports = [ 22 ];
            settings = {
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              PermitRootLogin = "no";
              AllowUsers = [ "pete" ];
            };
          };
        })

        (lib.mkIf config.enable.sync {
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

        (lib.mkIf config.services.samba-client {
          systemd.tmpfiles.rules = [
            "d /mnt/router 0755 pete pete -"
          ];
          environment.systemPackages = [ pkgs.cifs-utils ];
          sops.secrets."samba/server" = { };

          fileSystems = {
            "/mnt/server" = {
              device = "//192.168.88.241/private/";
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

        (lib.mkIf config.enable.ollama {
          services.ollama.enable = false;
          # Optional: Install ollama CLI for terminal use
          environment.systemPackages = [ pkgs.ollama ];
        })
      ];
    };
}
