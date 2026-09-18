{...}:{
  description = "Test packaging for raysha-filter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.raysha-filter =
        pkgs.writeShellApplication {
          name = "raysha-filter";

          runtimeInputs = with pkgs; [
            curl
            jq
          ];

          text = builtins.readFile ./scripts/raysha-filter.sh;
        };

      packages.${system}.default =
        self.packages.${system}.raysha-filter;
    };
}