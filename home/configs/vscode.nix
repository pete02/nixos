{ ... }:
{
  programs.vscode = {
    userSettings = {
      nix.serverPath = "nixd";
      nix.enableLanguageServer = true;
      nixpkgs = {
        expr = import <nixpkgs> { };
      };
      formatting = {
        command = [
          "treefmt"
        ];
      };
    };
  };
}
