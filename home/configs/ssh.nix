{ }:
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "servu" = {
        hostname = "example.com";
        user = "pete";
        identityFile = "~/.ssh/id_server";
        port = 22;
      };
    };
  };
}
