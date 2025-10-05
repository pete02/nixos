{lib,...}:
with lib;{
    options={
        services.ssh.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable ssh";
        };
    };
    config= mkIf services.ssh.enable{
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
    "ssh-rsa AAAAB3Nz....6OWM= user" # content of authorized_keys file
    # note: ssh-copy-id will add user@your-machine after the public key
    # but we can remove the "@your-machine" part
  ];
    };
}