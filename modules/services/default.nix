{ ... }:
{
  imports = [
    ./cleaner.nix
    ./gitwatcher.nix
    ./sshserver.nix
    ./sambaclients.nix
    ./syncing.nix
    ./wireguard-client.nix
    ./gpucooler.nix
    ./vms.nix
    ./ollama.nix
  ];
}
