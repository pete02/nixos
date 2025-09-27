nix-env --list-generations


sudo nix-env --delete-generations +5
sudo nix-collect-garbage

nix store optimize