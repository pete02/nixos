{ ... }:
{
  imports = [
    ./cleaner.nix
    ./autoupdater.nix
    ./gitwatcher.nix
    ./sshserver.nix
    ./sambaclients.nix
  ];
}
