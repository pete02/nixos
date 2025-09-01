{ config, pkgs, lib, ... }:
{
  options={
    fhs.enable = lib.mkEnableOption "enable fhs";
  };
  config = lib.mkIf config.fhs.enable{
    environment.systemPackages = with pkgs; [

    # Create an FHS environment using the command `fhs`, enabling the execution of non-NixOS packages in NixOS!
    (let base = pkgs.appimageTools.defaultFhsEnvArgs; in
      pkgs.buildFHSEnv (base // {
      name = "fhs";
      targetPkgs = pkgs: 
        # pkgs.appimageTools provides basic packages required by most software.
        (base.targetPkgs pkgs) ++ (with pkgs; [
          pkg-config
          ncurses'
          glibc
          lsb_release
          lsb
        ]
      );
      profile = "export FHS=1";
      runScript = "bash";
      extraOutputsToInstall = ["dev"];
    }))
  ];
  };
}