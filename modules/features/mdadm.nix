{inputs, ...}:
{
  flake.nixosModules.mdadm = {
    config, pkgs
  }:{

    environment.systemPackages = with pkgs; [
      mdadm
    ];

    environment.sessionVariables ={
      MAILADDR="petrik.rasanen@gmail.com";
    };

  };
}