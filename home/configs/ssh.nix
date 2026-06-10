{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      servu = {
        hostname = "192.168.88.241";
        user = "pete";
        identityFile = "~/.ssh/id_server";
        port = 22;
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/github_id";
      };
    };
  };
}
