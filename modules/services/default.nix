{ ... }:
{
  imports = [
    ./cleaner.nix
    ./autoupdater.nix
    ./gitwatcher.nix
    ./sshserver.nix
    ./sambaclients.nix
    ./syncing.nix
    ./wireguard-client.nix
    ./gpucooler.nix
    ./vms.nix
  ];
}
