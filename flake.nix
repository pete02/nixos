{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";
    sops-nix.url = "github:Mic92/sops-nix";
    shanocast.url ="github:rgerganov/shanocast";
  };
  inputs.vacuum-tube-src = {
    url = "github:shy1132/VacuumTube";
    flake = false;
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [(inputs.import-tree ./modules)];
    };
}
