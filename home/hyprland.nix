{pkgs, lib, config, ...}:
let 
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.wayback}/bin/waybar &

    sleep 1
  '';
in{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      exec-once = ''${startupScript}/bin/start'';

      input = {
        kb_layout = "fi";
      };

      "$mod" = "$SUPER";

      bindm = [
      "$mod, SPACE, exec, rofi -show drun -show-icons"
      ];
    };

    
  };
}