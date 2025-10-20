{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      servu = {
        hostname = "192.168.88.244";
        user = "pete";
        identityFile = "~/.ssh/id_server";
        port = 22;
      };
      my-nixos-repo = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_nixos_sync";
      };
    };
  };
}
