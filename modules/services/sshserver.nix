{lib, config, ...}:
with lib;{
    options={
        services.enable.ssh = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable ssh";
        };
    };
    config= mkIf config.services.ssh.enable{
    services.openssh = {
        enable = true;
        ports = [ 22 ];
        settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [ "myUser" ];
        };
    };
    services.fail2ban.enable = true;
  users.users.${config.username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcUoZ1iRFqNMy/cf3aVsvEmnwysuK8CAm1dHi6DbskN pete"
    # note: ssh-copy-id will add user@your-machine after the public key
    # but we can remove the "@your-machine" part
  ];
    };
}