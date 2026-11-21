{self, ...}: {
  flake.nixosModules.desktops = {lib, ...}: {
    options.desktop = {
      desktop = lib.mkOption {
        type = lib.types.enum ["none" "raysha" "talia" "alanna"];
        default = "none";
        description = "Select the desktop.";
      };

      monitors = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            output = lib.mkOption {
              type = lib.types.str;
              description = "Monitor output name.";
            };

            mode = lib.mkOption {
              type = lib.types.str;
              description = "Monitor resolution and refresh rate.";
            };

            position = lib.mkOption {
              type = lib.types.str;
              default = "0x0";
              description = "Monitor position.";
            };

            bitdepth = lib.mkOption {
              type = lib.types.nullOr (lib.types.ints.between 8 16);
              default = null;
              description = "Optional monitor color bit depth.";
            };
          };
        });

        default = [];
        description = "Monitor configurations.";
      };
    };

    imports =
      [
        ./_raysha.nix
        ./_talia.nix
        ./_alanna.nix
      ]
      ++ (with self.nixosModules; [
        desktops-hdmi-cec
      ]);
  };
}
