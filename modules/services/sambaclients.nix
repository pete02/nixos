{ lib, config, ... }:

let
  mkShareOptions = name: {
    enable = lib.mkEnableOption "Enable this SMB share";

    path = lib.mkOption {
      type = lib.types.str;
      description = "Local mount point for ${name}";
    };

    device = lib.mkOption {
      type = lib.types.str;
      description = "SMB device path for ${name}";
    };

    secret = lib.mkOption {
      type = lib.types.str;
    };

    uid = lib.mkOption {
      type = lib.types.str;
      default = "1000";
      description = "User ID for files";
    };

    gid = lib.mkOption {
      type = lib.types.str;
      default = "1000";
      description = "Group ID for files";
    };
  };
in
{
  options.smbShares = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = mkShareOptions "share";
        config = { };
      }
    );
    default = { };
    description = "Define SMB shares";
  };

  config = lib.mkIf (lib.hasAttr "smbShares" config) {
    # for each share that is enabled
    fileSystems = lib.foldl' (
      fs: acc:
      let
        share = config.smbShares.${fs};
      in
      if share.enable then
        acc
        // {
          "${share.path}" = {
            device = share.device;
            fsType = "cifs";
            options = [
              "x-systemd.automount"
              "noauto"
              "x-systemd.idle-timeout=60"
              "x-systemd.device-timeout=5s"
              "x-systemd.mount-timeout=5s"
              "credentials=/etc/smb/smb-secrets"
              "vers=3.0"
              "uid=${share.uid}"
              "gid=${share.gid}"
            ];
            neededForBoot = false;
          };
        }
      else
        acc
    ) { } (builtins.attrNames config.smbShares);
  };
}
