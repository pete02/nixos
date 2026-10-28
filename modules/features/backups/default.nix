{self, ...}: {
  flake.nixosModules.backups = {
    imports = with self.nixosModules; [
      bitwarden-backup
      git-sync
      rsync-backup
      restic-backup
    ];
  };
}
