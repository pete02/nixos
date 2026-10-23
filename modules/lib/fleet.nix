{lib, ...}: let
  domain = "local";
  capitalise = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (-1) s;
in {
  flake.lib.fleet = rec {
    inherit domain;
    fqdn = host: "${host}.${domain}";

    lan.subnet = "192.168.88.0/24";

    # One ntfy server; topic derived from the host name ("raysha" -> .../Raysha)
    ntfy.base = "https://ntfy.lumilukko.com";
    ntfyTopic = host: "${ntfy.base}/${capitalise host}";

    cache = {
      host = "aria";
      addr = "192.168.88.241"; # keep the IP; see caveats
      port = 8080;
      name = "main";
      publicKey = "main:i1t81gc6fOtVfDvKgpiL1LG5HjrWF7AtHD21rmbr1OI=";
      envSecret = "services/attic/env";
      pullTokenSecret = "services/attic/pull_token";
      apiEndpoint = "http://${cache.addr}:${toString cache.port}/";
      url = "http://${cache.addr}:${toString cache.port}/${cache.name}";
    };

    # host + share + mount + secret, defined once
    samba.shares = {
      server = {host = "aria"; mountPoint = "/mnt/server"; credentialsSecret = "samba/server";};
      timelock = {host = "aria"; mountPoint = "/mnt/timelock"; credentialsSecret = "samba/timelock";};
    };

    # Machines that aren't (or aren't only) NixOS hosts
    devices = {
      raysha.mac = "88:d8:2e:ba:62:29";
      alanna = {mac = "2C:CF:67:DA:15:86"; sshKeyFrom = "raysha";};
    };

    registry = {host = "aria"; port = 5001;}; # docker mirror in dev/tools.nix
  };
}