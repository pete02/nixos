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
    programs.fcast-receiver = {
      enable = true;
      openFirewall = true; # opens TCP 46899
    };

    # mDNS, so the phone can discover the Pi
    networking.firewall.allowedUDPPorts = [ 5353 ];

    # Start the receiver with the Plasma session
    environment.etc."xdg/autostart/fcast-receiver-kiosk.desktop".source = let
      item = pkgs.makeDesktopItem {
        name = "fcast-receiver-kiosk";
        desktopName = "FCast Receiver";
        exec = lib.getExe config.programs.fcast-receiver.package;
      };
    in "${item}/share/applications/fcast-receiver-kiosk.desktop";
    
  };
}
