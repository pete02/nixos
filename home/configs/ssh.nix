{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    configFile = "/home/pete/.ssh/config";
    matchBlocks = {
      servu = {
        hostname = "192.168.88.252";
        user = "pete";
        identityFile = "~/.ssh/id_server";
        port = 22;
      };
      nixosrepo = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_nixos_sync";
        IdentitiesOnly = "yes";
      };
    };
  };
}
