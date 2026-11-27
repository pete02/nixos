{
  config,
  lib,
  inputs,
  pkgs,
  self,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  tv-ui-app = self.packages.${system}.tv-ui-app;
  vacuum-tube = self.packages.${system}.vacuum-tube;
  shanocast = inputs.shanocast.packages.${system}.shanocast;
  user = config.users.users.${config.username};
  tmdbSecret = "${config.hostname}/tmdb_api_key";
in {
  # Living-room TV kiosk: Pegasus frontend in cage, launching Moonlight, tv-ui,
  # VacuumTube and Blueman, driven by the TV remote over HDMI-CEC.
  config = lib.mkIf (config.desktop.desktop == "alanna-test") {
    shells.plasma-bigscreen.enable = true;
    shells.plasma-bigscreen.enableKdeConnect = true;

    environment.systemPackages = [
      tv-ui-app
      pkgs.moonlight-qt
      vacuum-tube
      pkgs.blueman
      shanocast
    ];

    # Read by systemd as root, so no owner is needed.
    sops.secrets.${tmdbSecret} = {};
    sops.templates."tv-ui.env".content = ''
      TMDB_API_KEY=${config.sops.placeholder.${tmdbSecret}}
    '';

    connectivity.bluetooth = lib.mkDefault true;
    desktop.hdmi-cec.enable = true;

    # tv-ui's pointer websocket creates a uinput device
    hardware.uinput.enable = true;
    users.users.${config.username}.extraGroups = ["uinput"];

    # Sound
    services.pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
    };

    networking.firewall.allowedTCPPorts = [ 8008 8009 8010 ];
    networking.firewall.allowedUDPPortRanges = [
      { from = 32768; to = 65535; }
    ];

    systemd.user.services.shanocast = {
      description = "Shanocast Google Cast Receiver";
      after = [ "graphical-session.target" "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "graphical-session.target" ];
      environment = {
        SDL_VIDEODRIVER = "wayland";
      };
      serviceConfig = {
        WorkingDirectory = "%h";
        ExecStart = "${lib.getExe shanocast} -p /home/pete/generated_root_cast_receiver.key -d /home/pete/generated_root_cast_receiver.crt wlan0";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
