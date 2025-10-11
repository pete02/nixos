{
  lib,
  pkgs,
  config,
  nixpkgs,
  ...
}:
{
  options.enable.brave = lib.mkEnableOption "enables brave";
  config = lib.mkIf config.enable.brave {
    environment.systemPackages = [ pkgs.brave ];
    nixpkgs.overlays = [
      (self: super: {
        brave = super.brave.overrideAttrs (oldAttrs: {
          postInstall = (oldAttrs.postInstall or "") + ''
            substituteInPlace $out/share/applications/brave-browser.desktop \
              --replace "/bin/brave" "/bin/brave --ozone-platform=x11"
          '';
        });
      })
    ];

  };
}
