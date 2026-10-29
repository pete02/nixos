# Shared knobs for the installer targets (not your fleet hosts).
{
  username = "pete";
  initialPassword = "Oma2026#rpi"; # change me
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5ukVlkjndCUz16g+8ZJj8Qmr4gmrRzH2cteJYnFF7M raysha"
  ];
  timeZone = "UTC";
  locale = "en_US.UTF-8";
  stateVersion = "26.11";
}
