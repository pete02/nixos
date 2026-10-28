# Shared knobs for every host. Edit before building images.
{
  username = "admin";
  # Change this! Only used for first login; with sshKeys set, password SSH login is disabled.
  initialPassword = "changeme";
  sshKeys = [
    # "ssh-ed25519 AAAA... you@laptop"
  ];
  timeZone = "UTC";
  locale = "en_US.UTF-8";
  stateVersion = "25.11";
}
