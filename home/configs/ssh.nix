{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      servu = {
        hostname = "192.168.88.252";
        user = "pete";
        identityFile = "~/.ssh/id_server";
        port = 22;
      };
    };
  };
}
