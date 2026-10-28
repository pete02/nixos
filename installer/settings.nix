# Shared knobs for every host. Edit before building images.
{
  username = "pete";
  # Change this! Only used for first login; with sshKeys set, password SSH login is disabled.
  initialPassword = "changeme";
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5ukVlkjndCUz16g+8ZJj8Qmr4gmrRzH2cteJYnFF7M raysha"
  ];
  timeZone = "UTC";
  locale = "en_US.UTF-8";
  stateVersion = "26.11";
}
