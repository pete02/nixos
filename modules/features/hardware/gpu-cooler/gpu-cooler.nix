{inputs, ...}: {
  flake.nixosModules.hardware-gpucooler = {
    config,
    lib,
    pkgs,
    ...
  }: let
    gpu-cooler = lib.mkScript pkgs {
      name = "gpu-cooler";
      src = ./gpu-cooler.sh;

      runtimeInputs = with pkgs; [
        python313Packages.gputil
        gawk
      ];
    };
  in {
    options.gpucooler = lib.mkEnableOption "Enable GPU cooler";
    config = lib.mkIf config.gpucooler {
      systemd.services.gpu-fan-control = {
        description = "GPU Fan Control Service";
        wantedBy = ["multi-user.target"];
        after = ["multi-user.target"];

        serviceConfig = {
          ExecStart = "${gpu-cooler}/bin/gpu-cooler";
          Restart = "always";
          RestartSec = 1;
        };
      };
    };
  };
}
