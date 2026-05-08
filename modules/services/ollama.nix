{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.enable.ollama = lib.mkEnableOption "enable ollama service";

  config = lib.mkIf config.enable.ollama {
    services.ollama.enable = false;
    # Optional: Install ollama CLI for terminal use
    environment.systemPackages = [ pkgs.ollama ];
  };

}
