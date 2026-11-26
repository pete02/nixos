{
  config,
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  tv-ui-app = self.packages.${system}.tv-ui-app;
  vacuum-tube = self.packages.${system}.vacuum-tube;

  user = config.users.users.${config.username};
  tmdbSecret = "${config.hostname}/tmdb_api_key";

  # Entries shown in Pegasus
  metadataFile = pkgs.writeText "applications.metadata.pegasus.txt" ''
    collection: Applications
    shortname: apps
    launch: "{file.path}"

    game: Moonlight
    file: ${lib.getExe pkgs.moonlight-qt}
    developer: Moonlight Game Streaming Project
    genre: Streaming

    game: TV UI
    file: ${lib.getExe tv-ui-app}
    developer: Local TV UI
    genre: Applications

    game: VacuumTube
    file: ${lib.getExe vacuum-tube}
    developer: VacuumTube
    genre: Video

    game: Bluetooth
    file: ${lib.getExe' pkgs.blueman "blueman-manager"}
    developer: Blueman
    genre: Settings
  '';
in {
  # Living-room TV kiosk: Pegasus frontend in cage, launching Moonlight, tv-ui,
  # VacuumTube and Blueman, driven by the TV remote over HDMI-CEC.
  config = lib.mkIf (config.desktop.desktop == "alanna") {
    shells.cage = {
      enable = true;
      program = lib.getExe pkgs.pegasus-frontend;
      environment.QT_QPA_PLATFORM = "wayland";
      # TMDB_API_KEY reaches Pegasus and everything it launches
      environmentFiles = [config.sops.templates."tv-ui.env".path];
      # The unit doesn't reference the launcher entries (they're symlinked in
      # via tmpfiles), so restart when they change, i.e. when tv-ui,
      # Moonlight or VacuumTube get a new store path.
      restartTriggers = [metadataFile];
    };

    environment.systemPackages = [
      tv-ui-app
      self.inputs.nixos-raspberrypi.moonlight-qt
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

    systemd.tmpfiles.rules = [
      "d ${user.home}/.config/pegasus-frontend/metafiles 0755 ${config.username} ${user.group} - -"
      "L+ ${user.home}/.config/pegasus-frontend/metafiles/applications.metadata.pegasus.txt - - - - ${metadataFile}"
    ];

    # Sound
    services.pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
    };
  };
}
