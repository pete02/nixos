{ pkgs, ... }:
{
  programs.vscode.profiles.default = {

    userSettings = {
      "nix.serverPath" = "nixd";
      "nix.enableLanguageServer" = true;
      "nixpkgs" = "{ expr = import <nixpkgs> { }; };";
      "formatting" = {
        "command" = [
          "treefmt"
        ];
      };
    };
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
    ];
  };
}
