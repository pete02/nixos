{
  config,
  pkgs,
  lib,
  ...
}:

let
  gpuFanScript = pkgs.writeShellApplication {
    name = "gpu-fan-control";
    text = ''
      #!/bin/bash

      while true; do
        temp=$(/run/current-system/sw/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

        

        # Clamp temperature to 40–80°C
        if [ "$temp" -lt 40 ]; then temp=40; fi
        if [ "$temp" -gt 80 ]; then temp=80; fi

        # Scale to 0–255 PWM
        if [ "$temp" -le 55 ]; then
            speed=40      # very quiet fixed speed
        else
            speed=255
        fi
        # TODO: write PWM to correct hwmon path
        echo $speed > /sys/class/hwmon/hwmon1/pwm2
        echo $speed > /sys/class/hwmon/hwmon1/pwm5

        sleep 1
      done
    '';
  };
in
{
  options.services.enable.gpufan = lib.mkEnableOption "enable GPU fan control service";

  config = lib.mkIf config.services.enable.gpufan {
    systemd.services.gpu-fan-control = {
      description = "GPU Fan Control Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${gpuFanScript}/bin/gpu-fan-control";
        Restart = "always";
        RestartSec = 1;
      };
    };
  };
}
