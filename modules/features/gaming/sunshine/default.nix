{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.gaming-sunshine = {
    lib,
    pkgs,
    config,
    ...
  }: let
    sunshine-start = self.lib.mkScript pkgs {
      name = "sunshine-start";
      src = ./scripts/start.sh;
      runtimeInputs = with pkgs; [
        hyprland
      ];
    };
    sunshine-kill-rpcs3 = self.lib.mkScript pkgs {
      name = "sunshine-kill-rpcs3";
      src = ./scripts/kill-rpcs3.sh;
    };
    sunshine-launch-indy = self.lib.mkScript pkgs {
      name = "sunshine-launch-indy";
      src = ./scripts/launch-indy.sh;
      substitutions = {
        HOME = config.users.users.${config.username}.home;
      };
    };
    sunshine-stop = self.lib.mkScript pkgs {
      name = "sunshine-stop";
      src = ./scripts/stop.sh;
      runtimeInputs = with pkgs; [
        hyprland
      ];
    };
  in {
    options.gaming.sunshine = lib.mkEnableOption "Sunshine game streaming";

    config = lib.mkIf config.gaming.sunshine {
      environment.systemPackages = [
        sunshine-start
        sunshine-stop
        sunshine-kill-rpcs3
        sunshine-launch-indy
      ];

      services.sunshine = {
        enable = true;
        capSysAdmin = true;
        openFirewall = true;

        settings = {
          capture = "wlr";
          csrf_allowed_origins = "https://192.168.88.241:47990";

        };
      };

      systemd.user.services.sunshine = {
        wantedBy = ["default.target"];
      };

      hardware.uinput.enable = true;

      users.users.${config.username}.extraGroups = [
        "uinput"
      ];

      hardware.firmware = [
        (pkgs.runCommand "philips-edid" {} ''
          mkdir -p $out/lib/firmware/edid
          cp ${./philips.edid} $out/lib/firmware/edid/philips.bin
        '')
      ];

      boot.kernelParams = [
        "drm.edid_firmware=HDMI-A-1:edid/philips.bin"
        "video=HDMI-A-1:e"
      ];
    };
  };
}
