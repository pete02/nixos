{self, inputs, ...}:{
  flake.nixosModules.bitwardenBackup={config, lib, pkgs, ...}:let 
    bitwardenBackup = self.lib.mkScript pkgs {
        name = "bitwardenBackup";
        src = ./bitwardenBackup.sh;
        runtimeInputs = with pkgs; [
          docker
          zip
          rclone
          curl
          gnugrep
          coreutils
          gnused
        ];
      };
  in {
    options.bitwardenBackup = {
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
        default = "gdrive:bitwardenBackups";
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
        default = "https://ntfy.lumilukko.com/Raysha";
        description = "ntfy URL for backup failure notifications.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "03:00";
        description = "systemd OnCalendar expression for when to run.";
      };
    };
    config= lib.mkIf config.bitwardenBackup.enable {
        systemd.services.bitwardenBackup = {
          environment = {
            DATA_DIR = config.bitwardenBackup.dataDir;
            CONTAINER_NAME = config.bitwardenBackup.containerName; 
            RCLONE_REMOTE = config.bitwardenBackup.remote;
            KEEP = toString config.bitwardenBackup.keep;
            RCLONE_CONFIG = config.bitwardenBackup.rcloneConfigFile;
            NTFY_URL = config.bitwardenBackup.ntfyUrl;
          };
          after = ["network-online.target"];
          wants = ["network-online.target"];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${bitwardenBackup}/bin/bitwardeBbackup";
          };

          startAt = config.bitwardenBackup.schedule;
        };
      };
  };
}