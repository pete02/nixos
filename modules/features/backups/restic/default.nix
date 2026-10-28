
{self, ...}: {
  flake.nixosModules.restic-backup = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.backups.restic;

    runner = self.lib.mkScript pkgs {
      name = "restic-backup";
      src = ./restic-backup.sh;
      runtimeInputs = with pkgs; [
        restic
        util-linux # flock
        coreutils
        curl
      ];
      substitutions = {
        # Values are shell-escaped because they are inserted into the script.
        REPOSITORY = lib.escapeShellArg cfg.repository;
        PASSWORD_FILE = lib.escapeShellArg cfg.passwordFile;
        FOLDERS = lib.escapeShellArgs cfg.folders;
        EXCLUDES = lib.escapeShellArgs (
          lib.concatMap (pattern: ["--exclude" pattern]) cfg.exclude
        );
        EXTRA_ARGS = lib.escapeShellArgs cfg.extraArgs;
        PRUNE_OPTS = lib.escapeShellArgs cfg.pruneOpts;
        NTFY_SUCCESS = lib.escapeShellArg cfg.ntfySuccess;
        NTFY_FAILURE = lib.escapeShellArg cfg.ntfyFailure;
      };
    };

    exe = "${runner}/bin/restic-backup";

    environment = {
      # Shared by the scheduled and shutdown services.
      LOCKFILE = "/run/restic-backup/lock";
    };

    # Local repository and source paths must be mounted before running.
    localPaths = lib.filter (lib.hasPrefix "/") (
      [cfg.repository] ++ cfg.folders
    );
  in {
    options.backups.restic = {
      enable = lib.mkEnableOption "Restic snapshot backups";

      user = lib.mkOption {
        type = lib.types.str;
        default = config.username;
        example = "alice";
        description = ''
          User running the backup. Must be able to read every source folder,
          read the password file, and write to the repository.
        '';
      };

      repository = lib.mkOption {
        type = lib.types.str;
        example = "/mnt/backup/restic";
        description = ''
          Restic repository location. Supports local paths and remote
          repositories such as sftp:backup@aria:/srv/backups/hostname.
        '';
      };

      passwordFile = lib.mkOption {
        type = lib.types.str;
        example = "/run/secrets/restic-password";
        description = ''
          File containing the Restic repository password.
          The service user must be able to read this file.
        '';
      };

      folders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["/home/alice/documents" "/home/alice/code"];
        description = "Absolute paths of the folders to back up.";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["node_modules" "target" ".cache"];
        description = ''
          Restic exclusion patterns applied to every backup.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["--one-file-system"];
        description = "Additional arguments passed to restic backup.";
      };

      pruneOpts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
        ];
        example = [
          "--keep-daily 14"
          "--keep-weekly 8"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        description = ''
          Arguments passed to restic forget, followed by --prune.
          Retention applies to the snapshots in this repository.
        '';
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        example = "*-*-* 00:00:00";
        description = ''
          Systemd calendar expression for scheduled backups.
          Missed runs are made up when the machine starts.
        '';
      };

      runOnShutdown = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Also run a backup when shutting down or rebooting.";
      };

      shutdownTimeout = lib.mkOption {
        type = lib.types.str;
        default = "5min";
        description = ''
          Maximum time the shutdown backup may delay shutdown.
        '';
      };

      ntfyFailure = lib.mkOption {
        type = lib.types.str;
        default = self.lib.fleet.ntfyFailure config.hostname;
        description = "ntfy URL for backup failure notifications.";
      };

      ntfySuccess = lib.mkOption {
        type = lib.types.str;
        default = self.lib.fleet.ntfyBackup config.hostname;
        description = "ntfy URL for successful backup notifications.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.folders != [];
          message = ''
            backups.restic.folders must contain at least one folder
            when backups.restic.enable is true.
          '';
        }
        {
          assertion = cfg.repository != "";
          message = ''
            backups.restic.repository must be set when
            backups.restic.enable is true.
          '';
        }
        {
          assertion = cfg.passwordFile != "";
          message = ''
            backups.restic.passwordFile must be set when
            backups.restic.enable is true.
          '';
        }
        {
          assertion = lib.all (path: lib.hasPrefix "/" path) cfg.folders;
          message = "All backups.restic.folders paths must be absolute.";
        }
      ];

      systemd.tmpfiles.rules = [
        "d /run/restic-backup 0700 ${cfg.user} - -"
      ];

      systemd.services.restic-backup = {
        description = "Create and prune Restic backup snapshots";
        wants = ["network-online.target"];
        after = [
          "network-online.target"
          "nss-lookup.target"
          "local-fs.target"
        ];
        restartIfChanged = false;
        stopIfChanged = false;

        unitConfig.RequiresMountsFor = localPaths;

        inherit environment;

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          ExecStart = exe;
          Nice = 10;
          IOSchedulingClass = "idle";
          UMask = "0077";
        };
      };

      systemd.timers.restic-backup = {
        description = "Scheduled Restic backups";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.schedule;
          Persistent = true;
        };
      };

      systemd.services.restic-backup-shutdown =
        lib.mkIf cfg.runOnShutdown {
          description = "Create Restic backup on shutdown";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = [
            "network-online.target"
            "nss-lookup.target"
            "local-fs.target"
          ];

          restartIfChanged = false;
          stopIfChanged = false;

          unitConfig.RequiresMountsFor = localPaths;

          inherit environment;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = cfg.user;
            ExecStart = lib.getExe' pkgs.coreutils "true";
            ExecStop = exe;
            TimeoutStopSec = cfg.shutdownTimeout;
            UMask = "0077";
          };
        };
    };
  };
}
