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
          "path " = "/nix/store/15p0ac1xa3mrxngm4vvqppiy6qd8a86l-bash-interactive-5.3p3/bin/bash";
          "args" = [
            "--login"
            "-i"
          ];
        };
      };
      "terminal.integrated.defaultProfile.linux" = "nix-bash";
    };
    profiles.default.extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
    ];
  };
}
