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
  phoneMac = "ae:5b:21:48:c8:04";

  screencastLaunch = pkgs.writeShellApplication {
    name = "screencast-tv";
    runtimeInputs = with pkgs; [
      chromium
      iproute2
      iputils
      gnugrep
      gawk
      libnotify
    ];
    text = ''
      mac="${phoneMac}"

      find_ip() {
        ip neigh | awk -v m="$mac" 'tolower($5) == tolower(m) && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print $1; exit }'
      }

      phone_ip="$(find_ip || true)"

      # If not in neighbor table yet, send brief ARP/ping probes across 192.168.88.0/24
      if [ -z "$phone_ip" ]; then
        for i in $(seq 1 254); do
          ping -c 1 -W 1 "192.168.88.$i" >/dev/null 2>&1 &
        done
        wait
        phone_ip="$(find_ip || true)"
      fi

      if [ -z "$phone_ip" ]; then
        notify-send "ScreenCast" "Could not find phone ($mac) on 192.168.88.x" || true
        echo "Could not find IP for MAC $mac" >&2
        exit 1
      fi

      exec chromium \
        --kiosk \
        --no-first-run \
        --disable-session-crashed-bubble \
        "http://$phone_ip:8080/"
    '';
  };

  screencastDesktopItem = pkgs.makeDesktopItem {
    name = "screencast-tv";
    desktopName = "Phone ScreenCast";
    genericName = "Screen Mirroring";
    comment = "Find phone IP and open ScreenCast stream in kiosk mode";
    exec = lib.getExe screencastLaunch;
    icon = "video-display";
    categories = ["AudioVideo" "Video" "Network"];
    terminal = false;
  };
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
      pkgs.chromium
      pkgs.blueman
      screencastLaunch
      screencastDesktopItem
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