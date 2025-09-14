{ ... }:
{
  programs.vscode = {
    enable = true;
    userSettings = {
      "nix.serverPath" = "nixd";
      "nix.enableLanguageServer" = true;
      "nixpkgs" = "{ expr = import <nixpkgs> { }; };";
    };
  };
}
