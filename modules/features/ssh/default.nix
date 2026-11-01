{self, ...}: {
  flake.nixosModules.ssh = {
    lib,
    config,
    ...
  }: {
    options.ssh = {
      server.enable = lib.mkEnableOption "Enable the SSH service";
      server.passwordlogin = lib.mkEnableOption "Enable the SSH password login. Use with care";
    };
    options.ssh.client.enable = lib.mkEnableOption "Enable the SSH service";
    config = lib.mkMerge [
      (lib.mkIf (config.ssh.server.enable) {
        services.openssh = {
          enable = true;
          ports = [22];
          hostKeys = []; # stop NixOS auto-generating one; sops provides it below
          settings = {
            PasswordAuthentication = config.ssh.server.passwordlogin;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
            AllowUsers = [config.username];
            AuthorizedKeysFile = config.sops.templates."authorized_keys".path;
          };
        };

        sops.secrets =
          lib.mapAttrs' (hostname: _:
            lib.nameValuePair "ssh/hosts/${hostname}/public_key" {})
          self.lib.hosts
          // {
            "ssh/hosts/${config.hostname}/host_key/private" = {
              path = "/etc/ssh/ssh_host_ed25519_key";
              owner = "root";
              group = "root";
              mode = "0600";
              restartUnits = ["sshd.service"];
            };
          };

        sops.templates."authorized_keys" = {
          content =
            lib.concatMapStringsSep "\n"
            (hostname: config.sops.placeholder."ssh/hosts/${hostname}/public_key")
            (builtins.attrNames self.lib.hosts);

          owner = config.username;
          mode = "0400";
        };
      })
      (lib.mkIf (config.ssh.client.enable) {
        sops.secrets =
          {"ssh/hosts/${config.hostname}/private_key" = {owner = config.username;};}
          // lib.mapAttrs' (hostname: _:
            lib.nameValuePair "ssh/hosts/${hostname}/host_key/public" {})
          (lib.filterAttrs (_: host: host.sshServer) self.lib.hosts);
        sops.templates."ssh_known_hosts" = {
          content =
            lib.concatMapStringsSep "\n"
            (hostname: "${hostname}.local ${config.sops.placeholder."ssh/hosts/${hostname}/host_key/public"}")
            (builtins.attrNames (lib.filterAttrs (_: host: host.sshServer) self.lib.hosts));

          owner = config.username;
          mode = "0400";
        };

        environment.etc."ssh/ssh_config".text =
          lib.concatMapStringsSep "\n\n"
          (hostname: ''
            Host ${hostname}
              HostName ${hostname}.local
              IdentityFile /run/secrets/ssh/hosts/${config.hostname}/private_key
              UserKnownHostsFile ${config.sops.templates."ssh_known_hosts".path}
              Port 22
              User  ${config.username}
          '')
          (builtins.attrNames (lib.filterAttrs (_: host: host.sshServer) self.lib.hosts))
          + lib.concatMapStringsSep "\n\n"
          (hostname: ''
            Host ${hostname}-wg
              HostName ${self.lib.fleet.wireguard.hosts.${hostname}}
              HostKeyAlias ${hostname}.local
              IdentityFile /run/secrets/ssh/hosts/${config.hostname}/private_key
              UserKnownHostsFile ${config.sops.templates."ssh_known_hosts".path}
              Port 22
              User ${config.username}
          '')
          (builtins.attrNames self.lib.fleet.wireguard.hosts);
      })
    ];
  };
}
