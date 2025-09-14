{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
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
    extensions = with pkgs.vscode-utils.extensionsFromVscodeMarketplace; [
      {
        name = "Nix IDE";
        publisher = "Noortheen";
      }
    ];
  };
}
