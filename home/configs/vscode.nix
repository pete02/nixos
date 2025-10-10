{ pkgs, ... }:
{
  programs.vscode = {
    profiles.default.userSettings = {
      "nix.serverPath" = "nixd";
      "nix.enableLanguageServer" = true;
      "nixpkgs" = "{ expr = import <nixpkgs> { }; };";
      "formatting" = {
        "command" = [
          "treefmt"
        ];
      };
      "terminal.integrated.profiles.linux" = {
        "nix-bash" = {
          "path" = "${pkgs.bash}/bin/bash";
        };
      };
      "terminal.integrated.defaultProfile.linux" = "nix-bash";
    };
    profiles.default.extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      arrterian.nix-env-selector

    ];
  };
}
