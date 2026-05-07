{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.enable.ollama = lib.mkEnableOption "enable ollama service";

  config = lib.mkIf config.services.enable.ollama {
    services.ollama = {
      enable = true;
      acceleration = "cuda"; # Or "rocm" for AMD
    };

    # Optional: Install ollama CLI for terminal use
    environment.systemPackages = [ pkgs.ollama ];
  };

}
