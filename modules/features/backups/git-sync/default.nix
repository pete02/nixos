{self, ...}: {
  flake.nixosModules.git-sync = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.backups.git-sync;

    # One git-sync invocation per folder. A failure in one folder must not stop
    # the others, so each is run independently and the unit's status reflects any failure.
    runner = self.lib.mkScript pkgs {
      name = "git-sync";
      src = ./git-sync.sh;
      runtimeInputs = with pkgs; [
        coreutils
        curl
        git
        gnugrep
        findutils
        gnused
        openssh
      ];
      substitutions = {
        MESSAGE = cfg.commitMessage;
        DEPTH = toString cfg.depth;
        FOLDERS = lib.escapeShellArgs cfg.folders;
      };
    };
  in {
    options.backups.git-sync = {
      enable = lib.mkEnableOption "committing and pushing git repos in the configured folders on shutdown";

      user = lib.mkOption {
        type = lib.types.str;
        default = config.username;
        example = "alice";
        description = ''
          User to run git-sync as. This user's `~/.gitconfig` (name/email) and
          credentials (e.g. unencrypted SSH keys or a credential helper) are used,
          so it should be the user that owns the repositories.
        '';
      };

      folders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["/home/alice/code"];
        description = "Folders to scan for git repositories. Each is scanned up to `depth` levels deep.";
      };

      depth = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "Maximum directory depth to search for repositories.";
      };

      commitMessage = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "git-sync";
        description = "Commit message to use. If null, `Auto-commit: <timestamp>` is used.";
      };

      timeout = lib.mkOption {
        type = lib.types.str;
        default = "2min";
        description = ''
          Maximum time the sync may delay shutdown (systemd time span). If it
          takes longer, it is killed so the machine can still power off.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.folders != [];
          message = "services.git-sync.folders must contain at least one folder when services.git-sync.enable is true.";
        }
      ];

      # The unit "starts" at boot (doing nothing) and does its work when it is
      # stopped, which systemd does on shutdown/reboot. Stop order is the reverse
      # of start order, so ordering it after the network means the sync runs
      # while the network is still up.
      systemd.services.git-sync = {
        description = "Commit and push git repositories on shutdown";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = [
          "network-online.target"
          "nss-lookup.target"
          "local-fs.target"
        ];

        # Do not run the sync (i.e. stop the unit) on `nixos-rebuild switch`.
        restartIfChanged = false;
        stopIfChanged = false;

        environment = {
          # Never hang on a prompt during shutdown.
          GIT_TERMINAL_PROMPT = "0";
          GIT_SSH_COMMAND = "${lib.getExe' pkgs.openssh "ssh"} -o BatchMode=yes -o ConnectTimeout=10";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          ExecStart = lib.getExe' pkgs.coreutils "true";
          ExecStop = "${runner}/bin/git-sync";
          TimeoutStopSec = cfg.timeout;
        };
      };
    };
  };
}
