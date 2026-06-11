{ ... }:
{

  smb = {
    enable = true;
    router = true;
  };

  enable = {
    nvidia-host-legacy = true;
    docker = true;
  };

  services.enable = {
    ssh = true;
    gitops = true;
    gpufan = true;
  };
}
