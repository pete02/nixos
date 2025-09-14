{
  config,
  lib,
  pkgs,
  ...
}:
let
  vulkanDriverFiles = [
    "${config.hardware.nvidia.package}/share/vulkan/icd.d/nvidia_icd.x86_64.json"
    "${config.hardware.nvidia.package.lib32}/share/vulkan/icd.d/nvidia_icd.i686.json"
  ];
  nvidia-vulkan = pkgs.writeShellScriptBin "nvidia-vulkan" ''
    export VK_DRIVER_FILES="${lib.concatStringsSep ":" vulkanDriverFiles}"
    exec "$@"
  '';
in
{
  options = {
    enable.gaming = lib.mkEnableOption "enables gaming tools";
  };
  config = lib.mkIf config.enable.gaming {
    programs.steam.enable = true;
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };
    environment.systemPackages = with pkgs; [
      mangohud
      nvidia-vulkan
      protonup
    ];
    programs.gamemode.enable = true;
  };
}
