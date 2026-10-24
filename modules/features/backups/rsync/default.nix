{self, ...}: {
  flake.nixosModules.rsync-backup = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.backups.rsync;

    runner = self.lib.mkScript pkgs {
      name = "rsync-backup";
      src = ./rsync-backup.sh;
      runtimeInputs = with pkgs; [
        rsync
        openssh # remote destinations
        util-linux # flock
        coreutils # date
        gnused
        curl
      ];
      substitutions = {
        # Every value must be a string and shell-escaped, as it is pasted into the script.
        DESTINATION = lib.escapeShellArg cfg.destination;
        DELETE =
          if cfg.delete
          then "1"
          else "0";
        FOLDERS = lib.escapeShellArgs cfg.folders;
        EXCLUDES = lib.escapeShellArgs cfg.exclude;
        EXTRA_ARGS = lib.escapeShellArgs cfg.extraArgs;
        NTFY_SUCCESS = cfg.ntfySuccess;
        NTFY_FAILURE = cfg.ntfyFailure;
      };
    };
    exe = "${runner}/bin/rsync-backup";

    environment = {
      # Shared by the daily and the shutdown run, so they never overlap.
      LOCKFILE = "/run/rsync-backup/lock";
      # Never hang on a prompt, and give up quickly if the network is down.
      RSYNC_RSH =
        "${lib.getExe' pkgs.openssh "ssh"} -o BatchMode=yes -o ConnectTimeout=10"
        + lib.optionalString (cfg.sshKey != null) " -i ${lib.escapeShellArg cfg.sshKey} -o IdentitiesOnly=yes";
    };

    # Local paths involved: the backup must not run (and, on shutdown, must keep
    # running before they are unmounted) unless they are mounted. This also stops
    # a backup into an empty mount point on the root filesystem when a drive is unplugged.
    localPaths = lib.filter (lib.hasPrefix "/") ([cfg.destination] ++ cfg.folders);
  in {
    options.backups.rsync = {
      enable = lib.mkEnableOption "backing up folders with rsync, daily and on shutdown";

      user = lib.mkOption {
        type = lib.types.str;
        default = config.username;
        example = "alice";
        description = ''
          User to run the backup as. It must be able to read every folder and to
          write to the destination. For remote destinations, this user's SSH
          keys and `known_hosts` are used.
        '';
      };

      destination = lib.mkOption {
        type = lib.types.str;
        example = "/mnt/backup";
        description = ''
          Where to copy the folders. A local path (`/mnt/backup`) or a remote
          one (`user@host:/backups/raysha`). Each source path is recreated below
          it, so `/home/alice/code` ends up at `<destination>/home/alice/code`.
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
        description = "rsync exclude patterns, applied to every folder.";
      };

      delete = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Delete files from the destination that no longer exist in the source,
          so the destination mirrors the source. Off by default so that
          deleting something by accident does not also delete its backup.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["--bwlimit=5000" "--exclude-from=/etc/rsync-excludes"];
        description = "Extra arguments passed to rsync.";
      };

      sshKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/alice/.ssh/id_backup";
        description = ''
          SSH private key for remote destinations. It must not have a passphrase,
          because there is no ssh-agent when the service runs.
        '';
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        example = "*-*-* 03:00:00";
        description = ''
          When to run the regular backup (systemd calendar expression). A run
          missed because the machine was off is made up at the next boot.
        '';
      };

      runOnShutdown = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Also run a backup when the machine shuts down or reboots.";
      };

      shutdownTimeout = lib.mkOption {
        type = lib.types.str;
        default = "5min";
        description = ''
          Maximum time the shutdown backup may delay shutdown (systemd time
          span). If it takes longer, it is killed so the machine can still power
          off. The next run picks up where it left off.
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
        description = "ntfy URL for backup failure notifications.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.folders != [];
          message = "backups.rsync.folders must contain at least one folder when backups.rsync.enable is true.";
        }
        {
          assertion = cfg.destination != "";
          message = "backups.rsync.destination must be set when backups.rsync.enable is true.";
        }
      ];

      # The lock file lives here; both units use it.
      systemd.tmpfiles.rules = ["d /run/rsync-backup 0700 ${cfg.user} - -"];

      # Regular backup, started by the timer below.
      systemd.services.rsync-backup = {
        description = "Back up folders with rsync";
        wants = ["network-online.target"];
        after = ["network-online.target" "nss-lookup.target" "local-fs.target"];
        unitConfig.RequiresMountsFor = localPaths;
        inherit environment;
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          ExecStart = exe;
          # Stay out of the way of whatever the machine is doing.
          Nice = 10;
          IOSchedulingClass = "idle";
        };
      };

      systemd.timers.rsync-backup = {
        description = "Regular rsync backup";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.schedule;
          Persistent = true;
        };
      };

      # Shutdown backup. The unit "starts" at boot (doing nothing) and does its
      # work when it is stopped, which systemd does on shutdown/reboot. Stop order
      # is the reverse of start order, so ordering it after the network means the
      # backup runs while the network is still up.
      systemd.services.rsync-backup-shutdown = lib.mkIf cfg.runOnShutdown {
        description = "Back up folders with rsync on shutdown";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target" "nss-lookup.target" "local-fs.target"];
        unitConfig.RequiresMountsFor = localPaths;

        # Do not run the backup (i.e. stop the unit) on `nixos-rebuild switch`.
        restartIfChanged = false;
        stopIfChanged = false;

        inherit environment;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          ExecStart = lib.getExe' pkgs.coreutils "true";
          ExecStop = exe;
          TimeoutStopSec = cfg.shutdownTimeout;
        };
      };
    };
  };
}
