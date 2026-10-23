{self, ...}: {
  flake.nixosModules.bitwarden-backup = {
    config,
    lib,
    pkgs,
    ...
  }: let
    bitwarden-backup = self.lib.mkScript pkgs {
      name = "bitwarden-backup";
      src = ./bitwarden-backup.sh;
      runtimeInputs = with pkgs; [
        docker
        zip
        rclone
        curl
        gnugrep
        coreutils
        gnused
        inetutils # hostname
      ];
    };
  in {
    options.bitwarden-backup = {
      enable = lib.mkEnableOption "Bitwarden backup to Google Drive";

      dataDir = lib.mkOption {
        type = lib.types.str;
        example = "/var/lib/bitwarden";
        description = "Bitwarden data folder to back up.";
      };

      containerName = lib.mkOption {
        type = lib.types.str;
        default = "bitwarden";
        description = "Docker container to stop/start (used when systemdUnit is null).";
      };

      systemdUnit = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "docker-bitwarden.service";
        description = ''
          Set this if the container is managed by systemd (e.g. virtualisation.oci-containers).
          Stopping through systemd stops the unit from restarting the container mid-backup.
        '';
      };

      remote = lib.mkOption {
        type = lib.types.str;
        default = "gdrive:bitwarden-backups";
        description = "rclone destination as remote:folder. The part before the colon names the remote.";
      };

      rcloneConfigFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Path to the SOPS-managed rclone configuration file.
          The decrypted file must remain outside the Nix store.
        '';
      };

      keep = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Number of most recent backups to keep.";
      };

      ntfyUrl = lib.mkOption {
        type = lib.types.str;
        default = self.lib.fleet.ntfyTopic config.hostname;
        description = "ntfy URL for backup failure notifications.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "03:00";
        description = "systemd OnCalendar expression for when to run.";
      };
    };
    config = lib.mkIf config.bitwarden-backup.enable {
      systemd.services.bitwarden-backup = {
        environment = {
          DATA_DIR = config.bitwarden-backup.dataDir;
          CONTAINER_NAME = config.bitwarden-backup.containerName;
          RCLONE_REMOTE = config.bitwarden-backup.remote;
          KEEP = toString config.bitwarden-backup.keep;
          RCLONE_CONFIG = "/run/bitwarden-backup/rclone.conf";
          NTFY_URL = config.bitwarden-backup.ntfyUrl;
        };
        after = ["network-online.target"];
        wants = ["network-online.target"];
        # Initialize the writable configuration only when it does not exist.
        preStart = ''
          if [ ! -e /run/bitwarden-backup/rclone.conf ]; then
            ${pkgs.coreutils}/bin/install \
              -m 0600 \
              ${config.bitwarden-backup.rcloneConfigFile} \
              /run/bitwarden-backup/rclone.conf
          fi
        '';

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${bitwarden-backup}/bin/bitwarden-backup";
          RuntimeDirectory = "bitwarden-backup";
          RuntimeDirectoryMode = "0700";
          RuntimeDirectoryPreserve = "yes";
        };
        startAt = config.bitwarden-backup.schedule;
      };
    };
  };
}
