{ self, inputs, ... }: {
  flake.nixosModules.common =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      options = {
        common-tools = {
          # 3D Modeling Tools
          modeling = lib.mkEnableOption "3D modeling tools (FreeCAD, appimage-run)";

          # E-Book Management
          books = lib.mkEnableOption "E-book management tools (Calibre)";

          # School/Note-taking Tools
          school = lib.mkEnableOption "School tools (Obsidian, Wine)";
        };
      };

      config = lib.mkMerge [
        ({
          environment.systemPackages = with pkgs;[
            vim
            git
            tree
            groff
            htop
            unzip
            unrar
            lshw
          ];
        })

        # 3D Modeling Tools
        (lib.mkIf config.common-tools.modeling {
          environment.systemPackages = with pkgs; [
            freecad
            appimage-run
          ];
        })

        # E-Book Management
        (lib.mkIf config.common-tools.books {
          environment.systemPackages = with pkgs; [
            calibre
          ];
        })

        # School/Note-taking Tools
        (lib.mkIf config.common-tools.school {
          environment.systemPackages = with pkgs; [
            # Obsidian with Wayland support
            (obsidian.override {
              platformArgs = ["--ozone-platform=wayland"];
            })
            wineWow64Packages.waylandFull
          ];
        })
      ];
    };
}
