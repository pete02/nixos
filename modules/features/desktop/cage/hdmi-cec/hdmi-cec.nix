{...}: {
  flake.nixosModules.desktop-hdmi-cec = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.desktop.hdmi-cec;

    python = pkgs.python3.withPackages (ps: [
      ps.evdev
    ]);

    listener = pkgs.replaceVars ./listener.py {
      CEC_DEVICE = cfg.device;
      CEC_CTL = "${pkgs.v4l-utils}/bin/cec-ctl";
      STDBUF = "${pkgs.coreutils}/bin/stdbuf";
      PEGASUS_SERVICE = cfg.pegasusService;
    };
  in {
    options.desktop.hdmi-cec = {
      enable = lib.mkEnableOption "HDMI-CEC remote input";

      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/cec0";
        description = "CEC adapter device.";
      };

      pegasusService = lib.mkOption {
        type = lib.types.str;
        default = "cage-tty1.service";
        description = "Cage service to restart when returning to Pegasus.";
      };
    };

    config = lib.mkIf cfg.enable {
      boot.kernelModules = ["uinput"];

      systemd.services.hdmi-cec-remote = {
        description = "HDMI-CEC remote keyboard input";
        wantedBy = ["multi-user.target"];
        after = [
          "systemd-modules-load.service"
          "systemd-udev-settle.service"
        ];

        serviceConfig = {
          Type = "simple";

          ExecStartPre = "${pkgs.v4l-utils}/bin/cec-ctl -d ${cfg.device} --playback -S";

          ExecStart = "${python}/bin/python ${listener}";

          Restart = "always";
          RestartSec = "2s";
        };
      };
    };
  };
}
