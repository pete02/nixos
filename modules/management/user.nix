{
  lib,
  config,
  inputs,
  ...
}:
let
  cof = config;
in
{
  options.username = lib.mkOption {
    type = lib.types.str;
    description = "The username of the main user";
  };

  config = {
    users.users.${cof.username} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
    };
    home-manager = {
      useGlobalPkgs = true;
      extraSpecialArgs = { inherit inputs; };
      users = {
        "pete" = import ./../../home/${cof.networking.hostName}.nix;
      };
    };
  };
}
