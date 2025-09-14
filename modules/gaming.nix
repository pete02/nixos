{
  config,
  lib,
  pkgs,
  ...
}:
let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';
in
{
  options = {
    enable.gaming = lib.mkEnableOption "enables gaming tools";
  };
  config = lib.mkIf config.enable.gaming {
    programs.steam.enable = true;
    programs.gamescope.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
      nvidia-offload
      protonup
    ];
    programs.gamemode.enable = true;
  };
}
