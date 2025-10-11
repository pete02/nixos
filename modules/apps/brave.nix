{
  lib,
  pkgs,
  config,
  nixpkgs,
  ...
}:
let
  braveOverlay = (
    self: super: {
      brave = super.brave.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          substituteInPlace $out/share/applications/brave-browser.desktop \
            --replace "/bin/brave" "/bin/brave --ozone-platform=x11"
        '';
      });
    }
  );
in
{
  options.enable.brave = lib.mkEnableOption "Enable Brave browser";

  config = lib.mkIf config.enable.brave {
    nixpkgs.overlays = [ braveOverlay ];

    environment.systemPackages = with pkgs; [ brave ];
  };
}
