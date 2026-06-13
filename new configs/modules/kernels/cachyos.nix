{ self, inputs, ... }:{
  perSystem={pkgs, lib, ...}:{

    packages.cachyosKernel= inputs.nix-cachyos-kernel.packages.x86_64-linux.linux-cachyos-latest-zen4.override{
      nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
      nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
    };
  }
}