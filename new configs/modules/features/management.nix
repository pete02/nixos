{self,inputs, ...}:{
  flake.nixosModules.management={
    options= {
      username= lib.mkOption {
        type = lib.types.str;
        description = "The username of the main user";
      };
    };
    config={
      users.users.${config.username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "seat"
          "dialout"
          "uucp"
        ];
      };
    } 
  }
}