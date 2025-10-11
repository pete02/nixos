{
  lib,
  config,
  nixpkgs,
  ...
}:

let
  # Import nixpkgs with your overlay already applied
  pkgs-with-brave = import nixpkgs {
    system = "x86_64-linux";
    overlays = [
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
in
{
  options.enable.brave = lib.mkEnableOption "Enable Brave browser";

  config = lib.mkIf config.enable.brave {
    environment.systemPackages = with pkgs-with-brave; [ brave ];
  };
}
