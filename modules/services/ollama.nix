{ pkgs, lib, ... }:
{
  options.services.enable.ollama = lib.mkEnableOption "enable ollama service";

  services.ollama = lib.mkIf config.services.enable.ollama {
    enable = true;
    acceleration = "cuda"; # Or "rocm" for AMD
  };

  # Optional: Install ollama CLI for terminal use
  environment.systemPackages = [ pkgs.ollama ];
}
